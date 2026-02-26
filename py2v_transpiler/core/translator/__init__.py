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
        # Use emitter for structured output
        self.emitter = VCodeEmitter()
        # Internal buffer for visiting blocks (functions, loops, etc.)
        self.output: List[str] = []
        self._indent_level = 0
        self.in_main = True # Flag to track if we are at top-level
        self.current_class: Optional[str] = None # Track if we are inside a class definition
        self.current_class_generics: List[str] = [] # Track generics of current class
        self.current_class_bases: List[str] = [] # Track bases of current class
        self.current_class_is_unittest = False
        self._zip_counter = 0 # Counter for unique variable names in zip loops
        self.used_builtins = set() # Track used built-in helpers (sorted, reversed, etc)
        self.renamed_functions = {"main": "py_main"} # Map to rename functions (e.g. main -> py_main)
        self.name_remap = {} # Temporary variable renaming (e.g. x -> it in generators)
        self._walrus_assignments: List[str] = [] # Buffer for walrus operator assignments

        self.mapper = StdLibMapper()
        self.imported_modules: Dict[str, str] = {} # alias -> module_name
        self.imported_symbols: Dict[str, str] = {} # alias -> module_name.symbol

    def visit_Module(self, node: ast.Module) -> str:
        self.coroutine_handler.scan_module(node)

        for stmt in node.body:
            # Check if statement is top-level expression or assignment
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Import, ast.ImportFrom)):
                self.in_main = False
                self.visit(stmt)
                self.in_main = True
            else:
                # This is part of main body
                # We need to capture the output of this statement
                # But visit returns None and appends to self.output
                # So we need to manage self.output

                # Clear output buffer
                self.output = []
                self.visit(stmt)
                # Append buffer to main
                for line in self.output:
                    # Remove indentation if added by _indent() for main body
                    # Because generator adds indentation for main()
                    self.emitter.add_main_statement(line.strip())
                self.output = []

        if "sorted" in self.used_builtins:
            self.emitter.add_function(
                "fn py_sorted[T](a []T) []T {\n    mut b := a.clone()\n    b.sort()\n    return b\n}"
            )
        if "reversed" in self.used_builtins:
            self.emitter.add_function(
                "fn py_reversed[T](a []T) []T {\n    mut b := a.clone()\n    b.reverse()\n    return b\n}"
            )

        # Simple check for tempfile usage. `imported_modules` values are module names.
        # But we also need to check if we actually used the helpers, which are returned by mapper.
        # The mapper returns strings like "py_temp_dir()".
        # We can scan the emitted output for usage, but `self.output` is cleared.
        # However, `self.emitter` holds the full code.
        # Let's just check if `tempfile` was imported.
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
             # Check if used via from ... import ...
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
             # py_chain: variadic, generic, flattens arrays
             # Note: V generics with variadic args might be tricky.
             # fn py_chain[T](args ...[]T) []T
             self.emitter.add_function("fn py_chain[T](args ...[]T) []T {\n    mut res := []T{}\n    for arg in args {\n        res << arg\n    }\n    return res\n}")

             # py_repeat: returns array initialized with value
             self.emitter.add_function("fn py_repeat[T](val T, n int) []T {\n    return []T{len: n, init: val}\n}")

             # py_count: iterator struct
             self.emitter.add_struct("struct PyCountIterator {\nmut:\n    val int\n    step int\n}")
             self.emitter.add_function("fn (mut i PyCountIterator) next() ?int {\n    val := i.val\n    i.val += i.step\n    return val\n}")
             self.emitter.add_function("fn py_count(start int, step int) PyCountIterator {\n    return PyCountIterator{val: start, step: step}\n}")

             # py_cycle: iterator struct
             # Cycle needs to store the array and current index
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
             # py_reduce helper
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
             # xor in V is ^ for ints, but logic xor? (a != b)
             self.emitter.add_function("fn py_op_xor[T](a T, b T) T { return a ^ b }")

        threading_used = "threading" in self.imported_modules.values()
        if not threading_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("threading."):
                     threading_used = True
                     break

        if threading_used:
            # We need a PyThread struct. But standard threads in V (spawn) don't have join() unless we keep the handle.
            # V spawn returns a thread handle. `h := spawn foo()`. `h.wait()`.
            # Python: t = Thread(target=f, args=...); t.start(); t.join()
            # We can't easily emulate `start()` deferral without wrapping the function in a struct and spawning later.
            # Simplified: PyThread struct that holds the function? No, function types vary.
            # Compromise: Map `Thread` to a struct that does NOT hold the function, but assumes immediate start or
            # we just provide a dummy wrapper.
            # Actually, `visit_Call` will map `threading.Thread(...)`.
            # If we map it to `spawn`, it starts immediately.
            # Let's try to map `threading.Thread` to a struct `PyThread` and `start` to `spawn`.
            # BUT `start` is a method on the instance.
            # `t.start()` -> `t.handle = spawn t.run()`.
            # This requires `t` to know what `run` is.
            # This is complex for a simple transpiler.
            #
            # ALTERNATIVE:
            # Map `t = threading.Thread(target=f)` -> `t := PyThread{ task: fn() { f() } }` (closure?)
            # `t.start()` -> `t.handle = spawn t.task()`
            # `t.join()` -> `t.handle.wait()`
            #
            # Limitation: V closures support is evolving.
            # Also `target=f` might take args. `args=(1,)`. `fn() { f(1) }`.
            #
            # Let's emit a placeholder PyThread implementation that suggests manual adjustment or
            # limited support (no args, or specific signature).
            #
            # `struct PyThread { mut: handle thread int /* generic handle */ }`
            # `fn (mut t PyThread) start(f fn()) { t.handle = spawn f() }`
            # `fn (t PyThread) join() { t.handle.wait() }`

            self.emitter.add_struct("struct PyThread {\nmut:\n    handle thread int\n    // task fn() // V function types in structs?\n}")
            self.emitter.add_function("fn (mut t PyThread) start() {\n    // Implementation requires generic task storage or closures\n    println('PyThread.start() called. Note: V spawns immediately on `spawn`. This requires manual adjustment.')\n}")
            self.emitter.add_function("fn (mut t PyThread) join() {\n    t.handle.wait()\n}")

            # Map acquire/release for Lock (sync.Mutex)
            # sync.Mutex has .lock() and .unlock()
            # Python: .acquire(), .release()
            # We can't add methods to sync.Mutex (foreign type).
            # But we can wrap it or just rely on manual fix?
            # Or use a wrapper struct `PyLock`.
            # Let's use `sync.Mutex` and try to map methods in `visit_Call`.
            pass

        socket_used = "socket" in self.imported_modules.values()
        if not socket_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("socket."):
                     socket_used = True
                     break

        if socket_used:
            # Constants
            self.emitter.add_main_statement("const py_AF_INET = 2")
            self.emitter.add_main_statement("const py_SOCK_STREAM = 1")

            # PySocket struct
            # It needs to hold either a TcpListener or TcpConn, or both (union-like behavior)
            # V doesn't have tagged unions easily for this without sum types.
            # But sum types work. `type PySocketState = net.TcpListener | net.TcpConn`?
            # Or just use `net.TcpListener` and `net.TcpConn` as fields, one is none.
            #
            # Simplified:
            # struct PySocket {
            # mut:
            #   listener ?net.TcpListener
            #   conn ?net.TcpConn
            #   is_server bool
            #   bound_addr string
            #   bound_port int
            # }
            self.emitter.add_struct("struct PySocket {\nmut:\n    listener ?net.TcpListener\n    conn ?net.TcpConn\n    is_server bool\n    bound_addr string\n    bound_port int\n}")

            # py_socket_new
            self.emitter.add_function("fn py_socket_new(af int, type_ int) PySocket {\n    return PySocket{}\n}")

            # bind
            # args: address tuple (host, port)
            # In V, we just store it. Listen happens on listen().
            self.emitter.add_function("fn (mut s PySocket) bind(addr []string) {\n    // Expecting addr to be [host, port_str] or similar from transpiled tuple\n    // But tuple transpilation maps to array of strings? Or array of mixed?\n    // If tuple (str, int) -> struct? or array of sumtype?\n    // Assuming simplistic transpilation of tuple to array of strings/anys.\n    // Here we stub it.\n    s.bound_addr = addr[0]\n    // s.bound_port = addr[1].int() // pseudo\n}")

            # listen
            # s.listen(backlog)
            # In V: listener := net.listen_tcp(.ip, '$addr:$port') or { panic(err) }
            self.emitter.add_function("fn (mut s PySocket) listen(backlog int) {\n    s.is_server = true\n    l := net.listen_tcp(.ip6, '${s.bound_addr}:${s.bound_port}') or { panic(err) }\n    s.listener = l\n}")

            # accept
            # conn, addr = s.accept()
            # Returns (conn, addr)
            # V: l.accept() returns TcpConn.
            # We need to return (PySocket, addr_tuple)
            # But V functions return multi values.
            # We return (PySocket, []string)
            self.emitter.add_function("fn (mut s PySocket) accept() (PySocket, []string) {\n    if mut l := s.listener {\n        new_conn := l.accept() or { panic(err) }\n        // addr := new_conn.peer_addr()?\n        return PySocket{conn: new_conn}, ['127.0.0.1', '0']\n    }\n    panic('accept on non-listener')\n}")

            # connect
            # s.connect((host, port))
            self.emitter.add_function("fn (mut s PySocket) connect(addr []string) {\n    c := net.dial_tcp('${addr[0]}:${addr[1]}') or { panic(err) }\n    s.conn = c\n}")

            # send (bytes) -> write
            self.emitter.add_function("fn (mut s PySocket) send(data []u8) int {\n    if mut c := s.conn {\n        c.write(data) or { panic(err) }\n        return data.len\n    }\n    return 0\n}")

            # recv (bufsize) -> read
            self.emitter.add_function("fn (mut s PySocket) recv(bufsize int) []u8 {\n    if mut c := s.conn {\n        mut buf := []u8{len: bufsize}\n        n := c.read(mut buf) or { 0 }\n        return buf[..n]\n    }\n    return []u8{}\n}")

            # close
            self.emitter.add_function("fn (mut s PySocket) close() {\n    if mut c := s.conn {\n        c.close() or {}\n    }\n    if mut l := s.listener {\n        l.close() or {}\n    }\n}")

        pathlib_used = "pathlib" in self.imported_modules.values()
        if not pathlib_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("pathlib."):
                     pathlib_used = True
                     break

        if pathlib_used:
             # struct PyPath { path string }
             self.emitter.add_struct("struct PyPath {\n    path string\n}")

             # py_path_new
             self.emitter.add_function("fn py_path_new(p string) PyPath {\n    return PyPath{path: p}\n}")

             # operator /
             self.emitter.add_function("fn (p PyPath) / (other string) PyPath {\n    return PyPath{path: os.join_path(p.path, other)}\n}")

             # exists
             self.emitter.add_function("fn (p PyPath) exists() bool {\n    return os.exists(p.path)\n}")

             # is_dir
             self.emitter.add_function("fn (p PyPath) is_dir() bool {\n    return os.is_dir(p.path)\n}")

             # is_file
             self.emitter.add_function("fn (p PyPath) is_file() bool {\n    return os.is_file(p.path)\n}")

             # read_text
             self.emitter.add_function("fn (p PyPath) read_text() string {\n    return os.read_file(p.path) or { panic(err) }\n}")

             # write_text
             self.emitter.add_function("fn (p PyPath) write_text(text string) {\n    os.write_file(p.path, text) or { panic(err) }\n}")

             # str
             self.emitter.add_function("fn (p PyPath) str() string {\n    return p.path\n}")

        http_used = "urllib.request" in self.imported_modules.values() or "http.client" in self.imported_modules.values()
        if not http_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("urllib.request.") or sym.startswith("http.client."):
                     http_used = True
                     break

        if http_used:
             # PyHttpResponse
             self.emitter.add_struct("struct PyHttpResponse {\n    body string\n}")
             self.emitter.add_function("fn (r PyHttpResponse) read() string {\n    return r.body\n}")

             # py_urlopen
             self.emitter.add_function("fn py_urlopen(url string) PyHttpResponse {\n    resp := http.get(url) or { panic(err) }\n    return PyHttpResponse{body: resp.body}\n}")

             # PyHttpConnection (mock/wrapper for http.client)
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
             # PyCsvReader wrapper
             # Wraps csv.Reader. Needs iterator protocol.
             # V csv.Reader.read() returns ?[]string.
             self.emitter.add_struct("struct PyCsvReader {\nmut:\n    reader csv.Reader\n}")
             # Helper to init. f is os.File which implements io.Reader (in V).
             # But csv.new_reader expects io.Reader. os.File works.
             # Note: V's io.Reader interface requires `read(mut []u8) !int`.
             # os.File has it.
             self.emitter.add_function("fn py_csv_reader(f os.File) PyCsvReader {\n    return PyCsvReader{reader: csv.new_reader(f)}\n}")

             # next method for iteration
             # V loops `for x in iter` call `next() ?T`.
             self.emitter.add_function("fn (mut r PyCsvReader) next() ?[]string {\n    res := r.reader.read() or { return none }\n    return res\n}")

             # PyCsvWriter wrapper
             self.emitter.add_struct("struct PyCsvWriter {\nmut:\n    writer csv.Writer\n}")
             self.emitter.add_function("fn py_csv_writer(f os.File) PyCsvWriter {\n    return PyCsvWriter{writer: csv.new_writer(f)}\n}")

             # writerow
             self.emitter.add_function("fn (mut w PyCsvWriter) writerow(row []string) {\n    w.writer.write(row) or { panic(err) }\n}")

        sqlite3_used = "sqlite3" in self.imported_modules.values()
        if not sqlite3_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("sqlite3."):
                     sqlite3_used = True
                     break

        if sqlite3_used:
             # PySqliteConnection wrapping sqlite.DB
             self.emitter.add_struct("struct PySqliteConnection {\n    db sqlite.DB\n}")
             # py_sqlite_connect
             self.emitter.add_function("fn py_sqlite_connect(path string) PySqliteConnection {\n    db := sqlite.connect(path) or { panic(err) }\n    return PySqliteConnection{db: db}\n}")

             # PySqliteCursor
             # Needs ref to DB. V structs pass by value unless ref or handle. sqlite.DB is a handle (voidptr C.sqlite3).
             # It also needs to store results of last query for fetchall.
             self.emitter.add_struct("struct PySqliteCursor {\n    db sqlite.DB\nmut:\n    rows []sqlite.Row\n}")

             # cursor() method
             self.emitter.add_function("fn (c PySqliteConnection) cursor() PySqliteCursor {\n    return PySqliteCursor{db: c.db}\n}")

             # execute(sql)
             self.emitter.add_function("fn (mut c PySqliteCursor) execute(sql string) {\n    // Basic execute. For SELECT, store rows.\n    // V sqlite exec returns []Row.\n    // Note: sqlite.exec takes (query string) ![]Row\n    rows := c.db.exec(sql) or { panic(err) }\n    c.rows = rows\n}")

             # fetchall()
             self.emitter.add_function("fn (c PySqliteCursor) fetchall() []sqlite.Row {\n    return c.rows\n}")

             # commit()
             self.emitter.add_function("fn (c PySqliteConnection) commit() {\n    // V sqlite usually auto-commits or simple exec. No explicit commit API exposed in vlib/db/sqlite usually unless raw?\n    // But 'commit' is SQL. c.db.exec('COMMIT')?\n    // Let's execute COMMIT.\n    c.db.exec('COMMIT') or {}\n}")

             # close()
             self.emitter.add_function("fn (c PySqliteConnection) close() {\n    c.db.close() or {}\n}")

        subprocess_used = "subprocess" in self.imported_modules.values()
        if not subprocess_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("subprocess."):
                     subprocess_used = True
                     break

        if subprocess_used:
             # PyCompletedProcess
             self.emitter.add_struct("struct PyCompletedProcess {\n    returncode int\n    stdout string\n    stderr string\n}")

             # py_subprocess_run(args []string) PyCompletedProcess
             # os.execute(cmd string) returns Result.
             # We need to join args. V's os.execute takes a string command.
             # Joining args with spaces is naive but standard for simple shells.
             # Better: os.new_process? But that's more complex.
             # For now, simplistic join.
             self.emitter.add_function("fn py_subprocess_run(args []string) PyCompletedProcess {\n    cmd := args.join(' ')\n    res := os.execute(cmd)\n    return PyCompletedProcess{returncode: res.exit_code, stdout: res.output, stderr: ''}\n}")

             # py_subprocess_call(args []string) int
             self.emitter.add_function("fn py_subprocess_call(args []string) int {\n    cmd := args.join(' ')\n    return os.system(cmd)\n}")

        platform_used = "platform" in self.imported_modules.values()
        if not platform_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("platform."):
                     platform_used = True
                     break

        if platform_used:
             # py_platform_machine
             self.emitter.add_function("fn py_platform_machine() string {\n    return os.uname().machine\n}")

        hashlib_used = "hashlib" in self.imported_modules.values()
        if not hashlib_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("hashlib."):
                     hashlib_used = True
                     break

        if hashlib_used:
             # PyHashSha256
             self.emitter.add_struct("struct PyHashSha256 {\nmut:\n    data []u8\n}")
             self.emitter.add_function("fn py_hash_sha256(data []u8) PyHashSha256 {\n    return PyHashSha256{data: data}\n}")
             self.emitter.add_function("fn (mut h PyHashSha256) update(data []u8) {\n    h.data << data\n}")
             self.emitter.add_function("fn (h PyHashSha256) digest() []u8 {\n    return sha256.sum(h.data)\n}")
             self.emitter.add_function("fn (h PyHashSha256) hexdigest() string {\n    return sha256.hexhash(h.data)\n}")

             # PyHashMd5
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
             # py_urllib_unquote
             self.emitter.add_function("fn py_urllib_unquote(s string) string {\n    return urllib.query_unescape(s) or { s }\n}")

             # py_urlencode
             # V's Values.add takes (key, val). urlencode takes map.
             self.emitter.add_function("fn py_urlencode(params map[string]string) string {\n    mut v := urllib.new_values(map[string][]string{})\n    for key, val in params {\n        v.add(key, val)\n    }\n    return v.encode()\n}")

             # py_urlparse
             # Returns urllib.URL.
             # Python urlparse returns ParseResult (named tuple).
             # V's urllib.parse returns !URL.
             # We can just return urllib.URL, but Python attributes might differ.
             # Python: scheme, netloc, path, params, query, fragment
             # V: scheme, host, path, raw_query, fragment. (netloc ~= host, query ~= raw_query).
             # We might need a wrapper struct if we want exact field names, but for now let's return URL.
             # Helper handles the result unwrapping.
             self.emitter.add_function("fn py_urlparse(url string) urllib.URL {\n    return urllib.parse(url) or { urllib.URL{} }\n}")

        zlib_used = "zlib" in self.imported_modules.values()
        if not zlib_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("zlib."):
                     zlib_used = True
                     break

        if zlib_used:
             # py_zlib_compress
             self.emitter.add_function("fn py_zlib_compress(data []u8) []u8 {\n    return zlib.compress(data) or { panic(err) }\n}")
             # py_zlib_decompress
             self.emitter.add_function("fn py_zlib_decompress(data []u8) []u8 {\n    return zlib.decompress(data) or { panic(err) }\n}")

        gzip_used = "gzip" in self.imported_modules.values()
        if not gzip_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("gzip."):
                     gzip_used = True
                     break

        if gzip_used:
             # py_gzip_compress
             self.emitter.add_function("fn py_gzip_compress(data []u8) []u8 {\n    return gzip.compress(data) or { panic(err) }\n}")
             # py_gzip_decompress
             self.emitter.add_function("fn py_gzip_decompress(data []u8) []u8 {\n    return gzip.decompress(data) or { panic(err) }\n}")

        copy_used = "copy" in self.imported_modules.values()
        if not copy_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("copy."):
                     copy_used = True
                     break

        if copy_used:
             # py_copy
             # Generic shallow copy using V's compile-time reflection
             self.emitter.add_function("fn py_copy[T](x T) T {\n    $if T is $Array {\n        return x.clone()\n    } $else $if T is $Map {\n        return x.clone()\n    } $else {\n        return x\n    }\n}")
             # py_deepcopy
             # Alias to py_copy (shallow copy via clone) as best effort for now.
             # In V, clone() for collections usually copies elements.
             # If elements are structs, they are copied (value).
             # If elements are pointers, pointers are copied (shallow).
             # True deep copy requires recursion.
             self.emitter.add_function("fn py_deepcopy[T](x T) T {\n    // Note: This uses .clone() which may not be a full deep copy for nested references\n    $if T is $Array {\n        return x.clone()\n    } $else $if T is $Map {\n        return x.clone()\n    } $else {\n        return x\n    }\n}")

        struct_used = "struct" in self.imported_modules.values()
        if not struct_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("struct."):
                     struct_used = True
                     break

        if struct_used:
             # Stub for generic pack/unpack
             self.emitter.add_function("fn py_struct_pack(fmt string, args ...any) []u8 {\n    panic('struct.pack with dynamic format not implemented')\n    return []u8{}\n}")
             # Return []any is hard in V without sum types for all primitives. For now, stub return empty.
             self.emitter.add_function("fn py_struct_unpack(fmt string, data []u8) []int {\n    panic('struct.unpack with dynamic format not implemented')\n    return []int{}\n}")
             self.emitter.add_function("fn py_struct_calcsize(fmt string) int {\n    panic('struct.calcsize with dynamic format not implemented')\n    return 0\n}")

             # Little Endian Helpers
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

             # Big Endian Helpers
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


        return self.emitter.emit()
