import ast
from typing import Any, List, Optional, Dict

from py2v_transpiler.models.v_types import map_python_type_to_v
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.stdlib_map.mapper import StdLibMapper
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler

from .base import TranslatorBase
from .literals import LiteralsMixin
from .variables import VariablesMixin
from .control_flow import ControlFlowMixin
from .functions import FunctionsMixin
from .classes import ClassesMixin
from .expressions import ExpressionsMixin
from .imports import ImportsMixin

class VNodeVisitor(
    ImportsMixin,
    ExpressionsMixin,
    ClassesMixin,
    FunctionsMixin,
    ControlFlowMixin,
    VariablesMixin,
    LiteralsMixin,
    TranslatorBase
):
    def __init__(self, type_inference):
        self.type_inference = type_inference
        self.decorator_processor = DecoratorProcessor(self)
        self.coroutine_handler = CoroutineHandler()
        self.emitter = VCodeEmitter()
        self.output: List[str] = []
        self._indent_level = 0
        self.in_main = True
        self.current_class: Optional[str] = None
        self.current_class_generics: List[str] = []
        self.current_class_bases: List[str] = []
        self.current_class_is_unittest = False
        self._zip_counter = 0
        self.used_builtins = set()
        self.used_complex = False
        self.renamed_functions = {"main": "py_main"}
        self.name_remap = {}
        self._walrus_assignments: List[str] = []
        self.single_dispatch_functions: Dict[str, Dict[str, str]] = {}

        self.mapper = StdLibMapper()
        self.imported_modules: Dict[str, str] = {}
        self.imported_symbols: Dict[str, str] = {}

        self._loop_stack: List[Dict[str, Any]] = []

    def visit_Module(self, node: ast.Module) -> str:
        self.coroutine_handler.scan_module(node)

        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Import, ast.ImportFrom)):
                self.in_main = False
                self.visit(stmt)
                self.in_main = True
            else:
                self.output = []
                self.visit(stmt)
                for line in self.output:
                    self.emitter.add_main_statement(line.strip())
                self.output = []

        for func_name, registry in self.single_dispatch_functions.items():
            lines = []
            lines.append(f"fn {func_name}(arg any) {{")
            lines.append("    // Singledispatch implementation")

            default_impl = registry.get("default")

            first = True
            for type_name, impl_name in registry.items():
                if type_name == "default": continue
                v_type = type_name

                check = f"if arg is {v_type}"
                if not first:
                    check = f" else {check}"

                lines.append(f"    {check} {{")
                lines.append(f"        {impl_name}(arg)")
                lines.append("    }")
                first = False

            if default_impl:
                if first:
                     lines.append(f"    {default_impl}(arg)")
                else:
                     lines.append("    else {")
                     lines.append(f"        {default_impl}(arg)")
                     lines.append("    }")

            lines.append("}")
            self.emitter.add_function("\n".join(lines))

        # Helpers for new features
        # py_list_concat
        self.emitter.add_function("fn py_list_concat[T](args ...[]T) []T {\n    mut res := []T{}\n    for arg in args {\n        res << arg\n    }\n    return res\n}")

        # py_dict_merge
        self.emitter.add_function("fn py_dict_merge[K, V](args ...map[K]V) map[K]V {\n    mut res := map[K]V{}\n    for arg in args {\n        for k, v in arg {\n            res[k] = v\n        }\n    }\n    return res\n}")

        if "sorted" in self.used_builtins:
            self.emitter.add_function(
                "fn py_sorted[T](a []T) []T {\n    mut b := a.clone()\n    b.sort()\n    return b\n}"
            )
        if "reversed" in self.used_builtins:
            self.emitter.add_function(
                "fn py_reversed[T](a []T) []T {\n    mut b := a.clone()\n    b.reverse()\n    return b\n}"
            )

        if self.used_complex:
             self.emitter.add_struct("struct PyComplex {\n    re f64\n    im f64\n}")
             self.emitter.add_function("fn py_complex(re f64, im f64) PyComplex {\n    return PyComplex{re: re, im: im}\n}")
             self.emitter.add_function("fn (a PyComplex) + (b PyComplex) PyComplex {\n    return PyComplex{re: a.re + b.re, im: a.im + b.im}\n}")
             self.emitter.add_function("fn (a PyComplex) - (b PyComplex) PyComplex {\n    return PyComplex{re: a.re - b.re, im: a.im - b.im}\n}")
             self.emitter.add_function("fn (a PyComplex) * (b PyComplex) PyComplex {\n    return PyComplex{re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re}\n}")
             self.emitter.add_function("fn (a PyComplex) / (b PyComplex) PyComplex {\n    denom := b.re * b.re + b.im * b.im\n    return PyComplex{re: (a.re * b.re + a.im * b.im) / denom, im: (a.im * b.re - a.re * b.im) / denom}\n}")
             self.emitter.add_function("fn (z PyComplex) str() string {\n    sign := if z.im >= 0 { '+' } else { '-' }\n    im_abs := if z.im >= 0 { z.im } else { -z.im }\n    return '(${z.re}${sign}${im_abs}j)'\n}")

        if "tempfile" in self.imported_modules.values():
             self.emitter.add_struct("struct PyTempDir {\n    path string\n}")
             self.emitter.add_function("fn (d PyTempDir) close() {\n    os.rmdir_all(d.path) or {}\n}")
             self.emitter.add_function("fn py_temp_dir() PyTempDir {\n    p := os.mkdir_temp('') or { panic(err) }\n    return PyTempDir{path: p}\n}")
             self.emitter.add_function("fn py_named_temp_file() os.File {\n    f, _ := os.create_temp('') or { panic(err) }\n    return f\n}")

        if "logging" in self.imported_modules.values():
             self.emitter.add_function("fn py_get_logger(name string) log.Log {\n    mut l := log.Log{}\n    l.set_level(.info)\n    return l\n}")

        if "argparse" in self.imported_modules.values():
             self.emitter.add_struct("struct PyArgDef {\n    name string\n}")
             self.emitter.add_struct("struct PyArgumentParser {\n    mut:\n    definitions []PyArgDef\n}")
             self.emitter.add_function("fn py_argparse_new() PyArgumentParser {\n    return PyArgumentParser{}\n}")
             self.emitter.add_function("fn (mut p PyArgumentParser) add_argument(name string) {\n    p.definitions << PyArgDef{name: name}\n}")
             self.emitter.add_function("fn (mut p PyArgumentParser) parse_args() map[string]string {\n    mut args := map[string]string{}\n    // Placeholder manual parsing logic\n    for i := 0; i < os.args.len; i++ {\n        arg := os.args[i]\n        if arg.starts_with('--') {\n            key := arg[2..]\n            val := if i + 1 < os.args.len { os.args[i+1] } else { '' }\n            args[key] = val\n        }\n    }\n    return args\n}")

        pathlib_used = "pathlib" in self.imported_modules.values()
        if not pathlib_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("pathlib."):
                     pathlib_used = True
                     break

        collections_used = "collections" in self.imported_modules.values()
        if not collections_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("collections."):
                     collections_used = True
                     break

        if collections_used:
             self.emitter.add_function("fn py_counter[T](a []T) map[T]int {\n    mut m := map[T]int{}\n    for x in a {\n        m[x]++\n    }\n    return m\n}")

        itertools_used = "itertools" in self.imported_modules.values()
        if not itertools_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("itertools."):
                     itertools_used = True
                     break

        if itertools_used:
             self.emitter.add_function("fn py_chain[T](args ...[]T) []T {\n    mut res := []T{}\n    for arg in args {\n        res << arg\n    }\n    return res\n}")
             self.emitter.add_function("fn py_repeat[T](val T, n int) []T {\n    return []T{len: n, init: val}\n}")
             self.emitter.add_struct("struct PyCountIterator {\nmut:\n    val int\n    step int\n}")
             self.emitter.add_function("fn (mut i PyCountIterator) next() ?int {\n    val := i.val\n    i.val += i.step\n    return val\n}")
             self.emitter.add_function("fn py_count(start int, step int) PyCountIterator {\n    return PyCountIterator{val: start, step: step}\n}")
             self.emitter.add_struct("struct PyCycleIterator[T] {\n    data []T\nmut:\n    idx int\n}")
             self.emitter.add_function("fn (mut i PyCycleIterator[T]) next() ?T {\n    if i.data.len == 0 { return none }\n    val := i.data[i.idx]\n    i.idx = (i.idx + 1) % i.data.len\n    return val\n}")
             self.emitter.add_function("fn py_cycle[T](data []T) PyCycleIterator[T] {\n    return PyCycleIterator[T]{data: data}\n}")

        functools_used = "functools" in self.imported_modules.values()
        if not functools_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("functools."):
                     functools_used = True
                     break

        if functools_used:
             self.emitter.add_function("fn py_reduce[T](op fn (acc T, x T) T, iter []T) T {\n    if iter.len == 0 { panic('reduce() of empty sequence with no initial value') }\n    mut acc := iter[0]\n    for i in 1..iter.len {\n        acc = op(acc, iter[i])\n    }\n    return acc\n}")

        operator_used = "operator" in self.imported_modules.values()
        if not operator_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("operator."):
                     operator_used = True
                     break

        if operator_used:
             self.emitter.add_function("fn py_op_add[T](a T, b T) T { return a + b }")
             self.emitter.add_function("fn py_op_sub[T](a T, b T) T { return a - b }")
             self.emitter.add_function("fn py_op_mul[T](a T, b T) T { return a * b }")
             self.emitter.add_function("fn py_op_div[T](a T, b T) T { return a / b }")
             self.emitter.add_function("fn py_op_mod[T](a T, b T) T { return a % b }")
             self.emitter.add_function("fn py_op_eq[T](a T, b T) bool { return a == b }")
             self.emitter.add_function("fn py_op_ne[T](a T, b T) bool { return a != b }")
             self.emitter.add_function("fn py_op_lt[T](a T, b T) bool { return a < b }")
             self.emitter.add_function("fn py_op_le[T](a T, b T) bool { return a <= b }")
             self.emitter.add_function("fn py_op_gt[T](a T, b T) bool { return a > b }")
             self.emitter.add_function("fn py_op_ge[T](a T, b T) bool { return a >= b }")
             self.emitter.add_function("fn py_op_not(a bool) bool { return !a }")
             self.emitter.add_function("fn py_op_and(a bool, b bool) bool { return a && b }")
             self.emitter.add_function("fn py_op_or(a bool, b bool) bool { return a || b }")
             self.emitter.add_function("fn py_op_xor[T](a T, b T) T { return a ^ b }")

        threading_used = "threading" in self.imported_modules.values()
        if not threading_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("threading."):
                     threading_used = True
                     break

        if threading_used:
            self.emitter.add_struct("struct PyThread {\nmut:\n    handle thread int\n    // task fn() // V function types in structs?\n}")
            self.emitter.add_function("fn (mut t PyThread) start() {\n    // Implementation requires generic task storage or closures\n    println('PyThread.start() called. Note: V spawns immediately on `spawn`. This requires manual adjustment.')\n}")
            self.emitter.add_function("fn (mut t PyThread) join() {\n    t.handle.wait()\n}")
            pass

        socket_used = "socket" in self.imported_modules.values()
        if not socket_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("socket."):
                     socket_used = True
                     break

        if socket_used:
            self.emitter.add_main_statement("const py_AF_INET = 2")
            self.emitter.add_main_statement("const py_SOCK_STREAM = 1")
            self.emitter.add_struct("struct PySocket {\nmut:\n    listener ?net.TcpListener\n    conn ?net.TcpConn\n    is_server bool\n    bound_addr string\n    bound_port int\n}")
            self.emitter.add_function("fn py_socket_new(af int, type_ int) PySocket {\n    return PySocket{}\n}")
            self.emitter.add_function("fn (mut s PySocket) bind(addr []string) {\n    // Expecting addr to be [host, port_str] or similar from transpiled tuple\n    // But tuple transpilation maps to array of strings? Or array of mixed?\n    // If tuple (str, int) -> struct? or array of sumtype?\n    // Assuming simplistic transpilation of tuple to array of strings/anys.\n    // Here we stub it.\n    s.bound_addr = addr[0]\n    // s.bound_port = addr[1].int() // pseudo\n}")
            self.emitter.add_function("fn (mut s PySocket) listen(backlog int) {\n    s.is_server = true\n    l := net.listen_tcp(.ip6, '${s.bound_addr}:${s.bound_port}') or { panic(err) }\n    s.listener = l\n}")
            self.emitter.add_function("fn (mut s PySocket) accept() (PySocket, []string) {\n    if mut l := s.listener {\n        new_conn := l.accept() or { panic(err) }\n        // addr := new_conn.peer_addr()?\n        return PySocket{conn: new_conn}, ['127.0.0.1', '0']\n    }\n    panic('accept on non-listener')\n}")
            self.emitter.add_function("fn (mut s PySocket) connect(addr []string) {\n    c := net.dial_tcp('${addr[0]}:${addr[1]}') or { panic(err) }\n    s.conn = c\n}")
            self.emitter.add_function("fn (mut s PySocket) send(data []u8) int {\n    if mut c := s.conn {\n        c.write(data) or { panic(err) }\n        return data.len\n    }\n    return 0\n}")
            self.emitter.add_function("fn (mut s PySocket) recv(bufsize int) []u8 {\n    if mut c := s.conn {\n        mut buf := []u8{len: bufsize}\n        n := c.read(mut buf) or { 0 }\n        return buf[..n]\n    }\n    return []u8{}\n}")
            self.emitter.add_function("fn (mut s PySocket) close() {\n    if mut c := s.conn {\n        c.close() or {}\n    }\n    if mut l := s.listener {\n        l.close() or {}\n    }\n}")

        pathlib_used = "pathlib" in self.imported_modules.values()
        if not pathlib_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("pathlib."):
                     pathlib_used = True
                     break

        if pathlib_used:
             self.emitter.add_struct("struct PyPath {\n    path string\n}")
             self.emitter.add_function("fn py_path_new(p string) PyPath {\n    return PyPath{path: p}\n}")
             self.emitter.add_function("fn (p PyPath) / (other string) PyPath {\n    return PyPath{path: os.join_path(p.path, other)}\n}")
             self.emitter.add_function("fn (p PyPath) exists() bool {\n    return os.exists(p.path)\n}")
             self.emitter.add_function("fn (p PyPath) is_dir() bool {\n    return os.is_dir(p.path)\n}")
             self.emitter.add_function("fn (p PyPath) is_file() bool {\n    return os.is_file(p.path)\n}")
             self.emitter.add_function("fn (p PyPath) read_text() string {\n    return os.read_file(p.path) or { panic(err) }\n}")
             self.emitter.add_function("fn (p PyPath) write_text(text string) {\n    os.write_file(p.path, text) or { panic(err) }\n}")
             self.emitter.add_function("fn (p PyPath) str() string {\n    return p.path\n}")

        http_used = "urllib.request" in self.imported_modules.values() or "http.client" in self.imported_modules.values()
        if not http_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("urllib.request.") or sym.startswith("http.client."):
                     http_used = True
                     break

        if http_used:
             self.emitter.add_struct("struct PyHttpResponse {\n    body string\n}")
             self.emitter.add_function("fn (r PyHttpResponse) read() string {\n    return r.body\n}")
             self.emitter.add_function("fn py_urlopen(url string) PyHttpResponse {\n    resp := http.get(url) or { panic(err) }\n    return PyHttpResponse{body: resp.body}\n}")
             self.emitter.add_struct("struct PyHttpConnection {\n    host string\nmut:\n    resp PyHttpResponse\n}")
             self.emitter.add_function("fn py_http_connection(host string) PyHttpConnection {\n    return PyHttpConnection{host: host}\n}")
             self.emitter.add_function("fn (mut c PyHttpConnection) request(method string, path string) {\n    url := 'http://${c.host}${path}'\n    resp := http.fetch(http.FetchConfig{url: url, method: method}) or { panic(err) }\n    c.resp = PyHttpResponse{body: resp.body}\n}")
             self.emitter.add_function("fn (c PyHttpConnection) getresponse() PyHttpResponse {\n    return c.resp\n}")

        csv_used = "csv" in self.imported_modules.values()
        if not csv_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("csv."):
                     csv_used = True
                     break

        if csv_used:
             self.emitter.add_struct("struct PyCsvReader {\nmut:\n    reader csv.Reader\n}")
             self.emitter.add_function("fn py_csv_reader(f os.File) PyCsvReader {\n    return PyCsvReader{reader: csv.new_reader(f)}\n}")
             self.emitter.add_function("fn (mut r PyCsvReader) next() ?[]string {\n    res := r.reader.read() or { return none }\n    return res\n}")
             self.emitter.add_struct("struct PyCsvWriter {\nmut:\n    writer csv.Writer\n}")
             self.emitter.add_function("fn py_csv_writer(f os.File) PyCsvWriter {\n    return PyCsvWriter{writer: csv.new_writer(f)}\n}")
             self.emitter.add_function("fn (mut w PyCsvWriter) writerow(row []string) {\n    w.writer.write(row) or { panic(err) }\n}")

        sqlite3_used = "sqlite3" in self.imported_modules.values()
        if not sqlite3_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("sqlite3."):
                     sqlite3_used = True
                     break

        if sqlite3_used:
             self.emitter.add_struct("struct PySqliteConnection {\n    db sqlite.DB\n}")
             self.emitter.add_function("fn py_sqlite_connect(path string) PySqliteConnection {\n    db := sqlite.connect(path) or { panic(err) }\n    return PySqliteConnection{db: db}\n}")
             self.emitter.add_struct("struct PySqliteCursor {\n    db sqlite.DB\nmut:\n    rows []sqlite.Row\n}")
             self.emitter.add_function("fn (c PySqliteConnection) cursor() PySqliteCursor {\n    return PySqliteCursor{db: c.db}\n}")
             self.emitter.add_function("fn (mut c PySqliteCursor) execute(sql string) {\n    // Basic execute. For SELECT, store rows.\n    // V sqlite exec returns []Row.\n    // Note: sqlite.exec takes (query string) ![]Row\n    rows := c.db.exec(sql) or { panic(err) }\n    c.rows = rows\n}")
             self.emitter.add_function("fn (c PySqliteCursor) fetchall() []sqlite.Row {\n    return c.rows\n}")
             self.emitter.add_function("fn (c PySqliteConnection) commit() {\n    // V sqlite usually auto-commits or simple exec. No explicit commit API exposed in vlib/db/sqlite usually unless raw?\n    // But 'commit' is SQL. c.db.exec('COMMIT')?\n    // Let's execute COMMIT.\n    c.db.exec('COMMIT') or {}\n}")
             self.emitter.add_function("fn (c PySqliteConnection) close() {\n    c.db.close() or {}\n}")

        subprocess_used = "subprocess" in self.imported_modules.values()
        if not subprocess_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("subprocess."):
                     subprocess_used = True
                     break

        if subprocess_used:
             self.emitter.add_struct("struct PyCompletedProcess {\n    returncode int\n    stdout string\n    stderr string\n}")
             self.emitter.add_function("fn py_subprocess_run(args []string) PyCompletedProcess {\n    cmd := args.join(' ')\n    res := os.execute(cmd)\n    return PyCompletedProcess{returncode: res.exit_code, stdout: res.output, stderr: ''}\n}")
             self.emitter.add_function("fn py_subprocess_call(args []string) int {\n    cmd := args.join(' ')\n    return os.system(cmd)\n}")

        platform_used = "platform" in self.imported_modules.values()
        if not platform_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("platform."):
                     platform_used = True
                     break

        if platform_used:
             self.emitter.add_function("fn py_platform_machine() string {\n    return os.uname().machine\n}")

        hashlib_used = "hashlib" in self.imported_modules.values()
        if not hashlib_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("hashlib."):
                     hashlib_used = True
                     break

        if hashlib_used:
             self.emitter.add_struct("struct PyHashSha256 {\nmut:\n    data []u8\n}")
             self.emitter.add_function("fn py_hash_sha256(data []u8) PyHashSha256 {\n    return PyHashSha256{data: data}\n}")
             self.emitter.add_function("fn (mut h PyHashSha256) update(data []u8) {\n    h.data << data\n}")
             self.emitter.add_function("fn (h PyHashSha256) digest() []u8 {\n    return sha256.sum(h.data)\n}")
             self.emitter.add_function("fn (h PyHashSha256) hexdigest() string {\n    return sha256.hexhash(h.data)\n}")
             self.emitter.add_struct("struct PyHashMd5 {\nmut:\n    data []u8\n}")
             self.emitter.add_function("fn py_hash_md5(data []u8) PyHashMd5 {\n    return PyHashMd5{data: data}\n}")
             self.emitter.add_function("fn (mut h PyHashMd5) update(data []u8) {\n    h.data << data\n}")
             self.emitter.add_function("fn (h PyHashMd5) digest() []u8 {\n    return md5.sum(h.data)\n}")
             self.emitter.add_function("fn (h PyHashMd5) hexdigest() string {\n    return md5.hexhash(h.data)\n}")

        urllib_parse_used = "urllib.parse" in self.imported_modules.values()
        if not urllib_parse_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("urllib.parse."):
                     urllib_parse_used = True
                     break

        if urllib_parse_used:
             self.emitter.add_function("fn py_urllib_unquote(s string) string {\n    return urllib.query_unescape(s) or { s }\n}")
             self.emitter.add_function("fn py_urlencode(params map[string]string) string {\n    mut v := urllib.new_values(map[string][]string{})\n    for key, val in params {\n        v.add(key, val)\n    }\n    return v.encode()\n}")
             self.emitter.add_function("fn py_urlparse(url string) urllib.URL {\n    return urllib.parse(url) or { urllib.URL{} }\n}")

        zlib_used = "zlib" in self.imported_modules.values()
        if not zlib_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("zlib."):
                     zlib_used = True
                     break

        if zlib_used:
             self.emitter.add_function("fn py_zlib_compress(data []u8) []u8 {\n    return zlib.compress(data) or { panic(err) }\n}")
             self.emitter.add_function("fn py_zlib_decompress(data []u8) []u8 {\n    return zlib.decompress(data) or { panic(err) }\n}")

        gzip_used = "gzip" in self.imported_modules.values()
        if not gzip_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("gzip."):
                     gzip_used = True
                     break

        if gzip_used:
             self.emitter.add_function("fn py_gzip_compress(data []u8) []u8 {\n    return gzip.compress(data) or { panic(err) }\n}")
             self.emitter.add_function("fn py_gzip_decompress(data []u8) []u8 {\n    return gzip.decompress(data) or { panic(err) }\n}")

        copy_used = "copy" in self.imported_modules.values()
        if not copy_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("copy."):
                     copy_used = True
                     break

        if copy_used:
             self.emitter.add_function("fn py_copy[T](x T) T {\n    $if T is $Array {\n        return x.clone()\n    } $else $if T is $Map {\n        return x.clone()\n    } $else {\n        return x\n    }\n}")
             self.emitter.add_function("fn py_deepcopy[T](x T) T {\n    // Note: This uses .clone() which may not be a full deep copy for nested references\n    $if T is $Array {\n        return x.clone()\n    } $else $if T is $Map {\n        return x.clone()\n    } $else {\n        return x\n    }\n}")

        struct_used = "struct" in self.imported_modules.values()
        if not struct_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("struct."):
                     struct_used = True
                     break

        if struct_used:
             self.emitter.add_function("fn py_struct_pack(fmt string, args ...any) []u8 {\n    panic('struct.pack with dynamic format not implemented')\n    return []u8{}\n}")
             self.emitter.add_function("fn py_struct_unpack(fmt string, data []u8) []int {\n    panic('struct.unpack with dynamic format not implemented')\n    return []int{}\n}")
             self.emitter.add_function("fn py_struct_calcsize(fmt string) int {\n    panic('struct.calcsize with dynamic format not implemented')\n    return 0\n}")
             self.emitter.add_function("fn py_struct_pack_I_le(val u32) []u8 {\n    mut buf := []u8{len: 4}\n    binary.little_endian_put_u32(mut buf, val)\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_I_le(buf []u8) u32 {\n    return binary.little_endian_u32(buf)\n}")
             self.emitter.add_function("fn py_struct_pack_i_le(val int) []u8 {\n    mut buf := []u8{len: 4}\n    binary.little_endian_put_u32(mut buf, u32(val))\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_i_le(buf []u8) int {\n    return int(binary.little_endian_u32(buf))\n}")
             self.emitter.add_function("fn py_struct_pack_H_le(val u16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.little_endian_put_u16(mut buf, val)\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_H_le(buf []u8) u16 {\n    return binary.little_endian_u16(buf)\n}")
             self.emitter.add_function("fn py_struct_pack_h_le(val i16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.little_endian_put_u16(mut buf, u16(val))\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_h_le(buf []u8) i16 {\n    return i16(binary.little_endian_u16(buf))\n}")
             self.emitter.add_function("fn py_struct_pack_Q_le(val u64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.little_endian_put_u64(mut buf, val)\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_Q_le(buf []u8) u64 {\n    return binary.little_endian_u64(buf)\n}")
             self.emitter.add_function("fn py_struct_pack_q_le(val i64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.little_endian_put_u64(mut buf, u64(val))\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_q_le(buf []u8) i64 {\n    return i64(binary.little_endian_u64(buf))\n}")
             self.emitter.add_function("fn py_struct_pack_I_be(val u32) []u8 {\n    mut buf := []u8{len: 4}\n    binary.big_endian_put_u32(mut buf, val)\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_I_be(buf []u8) u32 {\n    return binary.big_endian_u32(buf)\n}")
             self.emitter.add_function("fn py_struct_pack_i_be(val int) []u8 {\n    mut buf := []u8{len: 4}\n    binary.big_endian_put_u32(mut buf, u32(val))\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_i_be(buf []u8) int {\n    return int(binary.big_endian_u32(buf))\n}")
             self.emitter.add_function("fn py_struct_pack_H_be(val u16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.big_endian_put_u16(mut buf, val)\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_H_be(buf []u8) u16 {\n    return binary.big_endian_u16(buf)\n}")
             self.emitter.add_function("fn py_struct_pack_h_be(val i16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.big_endian_put_u16(mut buf, u16(val))\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_h_be(buf []u8) i16 {\n    return i16(binary.big_endian_u16(buf))\n}")
             self.emitter.add_function("fn py_struct_pack_Q_be(val u64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.big_endian_put_u64(mut buf, val)\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_Q_be(buf []u8) u64 {\n    return binary.big_endian_u64(buf)\n}")
             self.emitter.add_function("fn py_struct_pack_q_be(val i64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.big_endian_put_u64(mut buf, u64(val))\n    return buf\n}")
             self.emitter.add_function("fn py_struct_unpack_q_be(buf []u8) i64 {\n    return i64(binary.big_endian_u64(buf))\n}")


        array_used = "array" in self.imported_modules.values()
        if not array_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("array."):
                     array_used = True
                     break

        if array_used:
             self.emitter.add_function("fn py_array[T](code string, init []T) []T {\n    // Best effort: ignoring typecode validation, returning typed array directly\n    return init\n}")

        fractions_used = "fractions" in self.imported_modules.values()
        if not fractions_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("fractions."):
                     fractions_used = True
                     break

        if fractions_used:
             self.emitter.add_function("fn py_fraction(val any) fractions.Fraction {\n    $if val is $int {\n        return fractions.fraction(i64(val), 1)\n    } $else $if val is $float {\n        return fractions.from_f64(f64(val))\n    } $else $if val is string {\n        // Simplistic string parsing not implemented in helper yet\n        return fractions.fraction(0, 1)\n    }\n    return fractions.fraction(0, 1)\n}")

        statistics_used = "statistics" in self.imported_modules.values()
        if not statistics_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("statistics."):
                     statistics_used = True
                     break

        if statistics_used:
             self.emitter.add_function("fn py_statistics_mean[T](data []T) f64 {\n    mut sum := f64(0)\n    for x in data {\n        sum += f64(x)\n    }\n    if data.len == 0 { return 0.0 }\n    return sum / f64(data.len)\n}")
             self.emitter.add_function("fn py_statistics_median[T](data []T) f64 {\n    if data.len == 0 { return 0.0 }\n    mut sorted_data := data.clone()\n    sorted_data.sort()\n    mid := sorted_data.len / 2\n    if sorted_data.len % 2 == 1 {\n        return f64(sorted_data[mid])\n    }\n    return (f64(sorted_data[mid-1]) + f64(sorted_data[mid])) / 2.0\n}")
             self.emitter.add_function("fn py_statistics_mode[T](data []T) T {\n    if data.len == 0 { panic('statistics.mode on empty data') }\n    mut counts := map[T]int{}\n    for x in data {\n        counts[x]++\n    }\n    mut max_count := 0\n    mut mode_val := data[0]\n    for val, count in counts {\n        if count > max_count {\n            max_count = count\n            mode_val = val\n        }\n    }\n    return mode_val\n}")
             self.emitter.add_function("fn py_statistics_variance[T](data []T) f64 {\n    if data.len < 2 { panic('statistics.variance requires at least two data points') }\n    m := py_statistics_mean(data)\n    mut sum_sq_diff := f64(0)\n    for x in data {\n        diff := f64(x) - m\n        sum_sq_diff += diff * diff\n    }\n    return sum_sq_diff / f64(data.len - 1)\n}")
             self.emitter.add_function("fn py_statistics_stdev[T](data []T) f64 {\n    return math.sqrt(py_statistics_variance(data))\n}")

        decimal_used = "decimal" in self.imported_modules.values()
        if not decimal_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("decimal."):
                     decimal_used = True
                     break

        if decimal_used:
             self.emitter.add_main_statement("type Decimal = f64")
             self.emitter.add_function("fn py_decimal(val any) Decimal {\n    $if val is $float {\n        return f64(val)\n    } $else $if val is $int {\n        return f64(val)\n    } $else $if val is string {\n        return val.f64()\n    }\n    return 0.0\n}")

        pickle_used = "pickle" in self.imported_modules.values()
        if not pickle_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("pickle."):
                     pickle_used = True
                     break

        if pickle_used:
             self.emitter.add_function("fn py_pickle_dumps[T](obj T) string {\n    // Warning: Mapped to JSON serialization as partial replacement for pickle\n    return json.encode(obj)\n}")
             self.emitter.add_function("fn py_pickle_loads[T](s string) T {\n    // Warning: Mapped to JSON deserialization as partial replacement for pickle\n    return json.decode(T, s) or { panic(err) }\n}")
             self.emitter.add_function("fn py_pickle_dump[T](obj T, f os.File) {\n    // Warning: Mapped to JSON serialization\n    s := json.encode(obj)\n    f.write_string(s) or { panic(err) }\n}")
             self.emitter.add_function("fn py_pickle_load[T](f os.File) T {\n    // Warning: Mapped to JSON deserialization\n    // This assumes the file contains one JSON object\n    // We need to read whole file? or stream?\n    // V json.decode takes string.\n    // We can't easily read from file inside generic func without reading all.\n    // Assuming small file for now, but we don't have read_all on File struct easily exposed in standard way? \n    // actually os.read_file(path) exists. But here we have File object.\n    // Let's panic for now or return zero.\n    panic('pickle.load not fully implemented')\n    return T{}\n}")

        return self.emitter.emit()
