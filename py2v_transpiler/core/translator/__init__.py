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
        self.used_complex = False
        self.used_list_concat = False
        self.used_dict_merge = False
        self.used_string_format = False
        self.renamed_functions = {"main": "py_main"} # Map to rename functions (e.g. main -> py_main)
        self.name_remap = {} # Temporary variable renaming (e.g. x -> it in generators)
        self._walrus_assignments: List[str] = [] # Buffer for walrus operator assignments
        self.single_dispatch_functions: Dict[str, Dict[str, str]] = {} # dispatcher_name -> {type_name -> impl_func_name}
        self.function_names: Set[str] = set()
        self.finally_stack: List[ast.Try] = [] # Stack of active try-finally blocks
        self.loop_stack: List[Dict[str, Any]] = [] # Stack of active loops for break/continue tracking
        self.unique_id_counter: int = 0
        self.vexc_depth: int = 0

        self.mapper = StdLibMapper()
        self.imported_modules: Dict[str, str] = {} # alias -> module_name
        self.imported_symbols: Dict[str, str] = {} # alias -> module_name.symbol

    def visit_Module(self, node: ast.Module) -> str:
        self.coroutine_handler.scan_module(node)

        # Pre-scan for complex numbers to ensure struct is emitted
        # Actually, literals might be nested. `self.visit` updates `used_complex`.
        # But we emit helpers at the end. Correct.

        # Check module docstring
        if node.body and isinstance(node.body[0], ast.Expr) and isinstance(node.body[0].value, ast.Constant) and isinstance(node.body[0].value.value, str):
            # This is a docstring
            doc = node.body[0].value.value.strip()
            # Emit as comments at top of file (via main statements, but main comes last usually)
            # Actually, `add_main_statement` appends to main block.
            # Ideally docstrings should be at top of file.
            # Emitter has imports, structs, functions. Does it have "header comments"?
            # Let's emit it as a comment in main for now or try to put it in imports?
            # Emitter doesn't seem to have a dedicated header slot.
            # Let's put it as comment in main.
            for line in doc.splitlines():
                self.emitter.add_main_statement(f"// {line}")
            # Skip first statement
            body = node.body[1:]
        else:
            body = node.body

        for stmt in body:
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

        # Generate single dispatchers
        for func_name, registry in self.single_dispatch_functions.items():
            # fn func_name(arg Any) {
            #     match typeof(arg).name {
            #         'int' { func_name_int(arg) }
            #         'string' { func_name_string(arg) }
            #         else { func_name_base(arg) }
            #     }
            # }
            # Note: arguments matching is tricky because V `any` loses static info?
            # Actually, `typeof(arg).name` works on `any`.
            # But calling specific impl needs cast if it expects specific type.
            # `func_name_int(arg)` expects `int`, but arg is `any`.
            # We need `func_name_int(arg as int)`.
            # V syntax for casting from interface/any: `if arg is int { func_name_int(arg) }`

            lines = []
            lines.append(f"fn {func_name}(arg Any) {{")
            lines.append("    // Singledispatch implementation")

            # Default implementation
            default_impl = registry.get("default")

            first = True
            for type_name, impl_name in registry.items():
                if type_name == "default": continue

                # Check for supported types map
                v_type = type_name # Already mapped in register decorator handling

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

        if "sorted" in self.used_builtins:
            self.emitter.add_function(
                "fn py_sorted[T](a []T) []T {\n    mut b := a.clone()\n    b.sort()\n    return b\n}"
            )
        if "reversed" in self.used_builtins:
            self.emitter.add_function(
                "fn py_reversed[T](a []T) []T {\n    mut b := a.clone()\n    b.reverse()\n    return b\n}"
            )

        if "round" in self.used_builtins:
            self.emitter.add_function(
                "fn py_round(number f64, ndigits int) f64 {\n    p := math.pow(10, f64(ndigits))\n    return math.round(number * p) / p\n}"
            )

        if self.used_complex:
             self.emitter.add_struct("struct PyComplex {\n    re f64\n    im f64\n}")
             self.emitter.add_function("fn py_complex(re f64, im f64) PyComplex {\n    return PyComplex{re: re, im: im}\n}")
             self.emitter.add_function("fn (a PyComplex) + (b PyComplex) PyComplex {\n    return PyComplex{re: a.re + b.re, im: a.im + b.im}\n}")
             self.emitter.add_function("fn (a PyComplex) - (b PyComplex) PyComplex {\n    return PyComplex{re: a.re - b.re, im: a.im - b.im}\n}")
             self.emitter.add_function("fn (a PyComplex) * (b PyComplex) PyComplex {\n    return PyComplex{re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re}\n}")
             self.emitter.add_function("fn (a PyComplex) / (b PyComplex) PyComplex {\n    denom := b.re * b.re + b.im * b.im\n    return PyComplex{re: (a.re * b.re + a.im * b.im) / denom, im: (a.im * b.re - a.re * b.im) / denom}\n}")
             self.emitter.add_function("fn (z PyComplex) str() string {\n    sign := if z.im >= 0 { '+' } else { '-' }\n    im_abs := if z.im >= 0 { z.im } else { -z.im }\n    return '(${z.re}${sign}${im_abs}j)'\n}")

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
             for sym in self.imported_symbols.values():
                 if sym.startswith("pathlib."):
                     pathlib_used = True
                     break

        # Check for collections usage
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
             self.emitter.add_function("fn py_struct_pack(fmt string, args ...Any) []u8 {\n    panic('struct.pack with dynamic format not implemented')\n    return []u8{}\n}")
             # Return []Any is hard in V without sum types for all primitives. For now, stub return empty.
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


        array_used = "array" in self.imported_modules.values()
        if not array_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("array."):
                     array_used = True
                     break

        if array_used:
             # py_array helper
             # We rely on V's compile time branching. But initializer T is unknown.
             # Initializer is likely an array literal []int or []f64 passed from mapper.
             # But mapper passes it as string.
             # Wait, `py_array('i', [1,2])`. `initializer` is `[1,2]` (V code).
             # In V: `py_array(typecode string, init []int)`. But init type varies.
             # We can't define `py_array` generically over *unrelated* input types easily unless we use sum type or any?
             # Or we define overload? V doesn't support overloads.
             # `fn py_array[T](code string, init []T) []T` ?
             # If code is 'i', T must be int. If code is 'd', T must be f64.
             # The user code will look like `py_array('i', [1,2])`.
             # `[1,2]` is `[]int`. So T is `int`.
             # `py_array('d', [1.0])`. `[1.0]` is `[]f64`. So T is `f64`.
             # So a single generic function works!
             # We just need to assert/check typecode matches T? Or just ignore typecode and trust T?
             # Python uses typecode to coerce. `array('i', [1.0])` -> `[1]`.
             # If we just return `init`, we lose coercion.
             # But V is strict. `[1.0]` is `[]f64`. If we want `[]int`, we need to cast.
             # But we can't easily cast `[]f64` to `[]int` inside generic `py_array[T]`.
             # Let's assume correct input type for now, or just return `init`.
             self.emitter.add_function("fn py_array[T](code string, init []T) []T {\n    // Best effort: ignoring typecode validation, returning typed array directly\n    return init\n}")

        fractions_used = "fractions" in self.imported_modules.values()
        if not fractions_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("fractions."):
                     fractions_used = True
                     break

        if fractions_used:
             # py_fraction helper for single argument (int, float, string)
             # V fractions.fraction(n, d) is for two ints.
             # fractions.from_f64(f) exists.
             # Parsing string requires custom logic or libc atof?
             # For now, simplistic implementation for int/float/string
             self.emitter.add_function("fn py_fraction(val Any) fractions.Fraction {\n    $if val is $int {\n        return fractions.fraction(i64(val), 1)\n    } $else $if val is $float {\n        return fractions.from_f64(f64(val))\n    } $else $if val is string {\n        // Simplistic string parsing not implemented in helper yet\n        return fractions.fraction(0, 1)\n    }\n    return fractions.fraction(0, 1)\n}")

        statistics_used = "statistics" in self.imported_modules.values()
        if not statistics_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("statistics."):
                     statistics_used = True
                     break

        if statistics_used:
             # py_statistics_mean
             self.emitter.add_function("fn py_statistics_mean[T](data []T) f64 {\n    mut sum := f64(0)\n    for x in data {\n        sum += f64(x)\n    }\n    if data.len == 0 { return 0.0 }\n    return sum / f64(data.len)\n}")

             # py_statistics_median
             self.emitter.add_function("fn py_statistics_median[T](data []T) f64 {\n    if data.len == 0 { return 0.0 }\n    mut sorted_data := data.clone()\n    sorted_data.sort()\n    mid := sorted_data.len / 2\n    if sorted_data.len % 2 == 1 {\n        return f64(sorted_data[mid])\n    }\n    return (f64(sorted_data[mid-1]) + f64(sorted_data[mid])) / 2.0\n}")

             # py_statistics_mode
             self.emitter.add_function("fn py_statistics_mode[T](data []T) T {\n    if data.len == 0 { panic('statistics.mode on empty data') }\n    mut counts := map[T]int{}\n    for x in data {\n        counts[x]++\n    }\n    mut max_count := 0\n    mut mode_val := data[0]\n    for val, count in counts {\n        if count > max_count {\n            max_count = count\n            mode_val = val\n        }\n    }\n    return mode_val\n}")

             # py_statistics_variance
             self.emitter.add_function("fn py_statistics_variance[T](data []T) f64 {\n    if data.len < 2 { panic('statistics.variance requires at least two data points') }\n    m := py_statistics_mean(data)\n    mut sum_sq_diff := f64(0)\n    for x in data {\n        diff := f64(x) - m\n        sum_sq_diff += diff * diff\n    }\n    return sum_sq_diff / f64(data.len - 1)\n}")

             # py_statistics_stdev
             self.emitter.add_function("fn py_statistics_stdev[T](data []T) f64 {\n    return math.sqrt(py_statistics_variance(data))\n}")

        decimal_used = "decimal" in self.imported_modules.values()
        if not decimal_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("decimal."):
                     decimal_used = True
                     break

        if decimal_used:
             # py_decimal helper
             # Map Decimal to f64 for now
             self.emitter.add_main_statement("type Decimal = f64")
             self.emitter.add_function("fn py_decimal(val Any) Decimal {\n    $if val is $float {\n        return f64(val)\n    } $else $if val is $int {\n        return f64(val)\n    } $else $if val is string {\n        return val.f64()\n    }\n    return 0.0\n}")

        pickle_used = "pickle" in self.imported_modules.values()
        if not pickle_used:
             for sym in self.imported_symbols.values():
                 if sym.startswith("pickle."):
                     pickle_used = True
                     break

        if pickle_used:
             # py_pickle_dumps
             self.emitter.add_function("fn py_pickle_dumps[T](obj T) string {\n    // Warning: Mapped to JSON serialization as partial replacement for pickle\n    return json.encode(obj)\n}")
             # py_pickle_loads
             self.emitter.add_function("fn py_pickle_loads[T](s string) T {\n    // Warning: Mapped to JSON deserialization as partial replacement for pickle\n    return json.decode(T, s) or { panic(err) }\n}")
             # py_pickle_dump (to file)
             self.emitter.add_function("fn py_pickle_dump[T](obj T, f os.File) {\n    // Warning: Mapped to JSON serialization\n    s := json.encode(obj)\n    f.write_string(s) or { panic(err) }\n}")
             # py_pickle_load (from file) - hard because we need to read everything?
             # Or assume file content is valid json.
             self.emitter.add_function("fn py_pickle_load[T](f os.File) T {\n    // Warning: Mapped to JSON deserialization\n    // This assumes the file contains one JSON object\n    // We need to read whole file? or stream?\n    // V json.decode takes string.\n    // We can't easily read from file inside generic func without reading all.\n    // Assuming small file for now, but we don't have read_all on File struct easily exposed in standard way? \n    // actually os.read_file(path) exists. But here we have File object.\n    // Let's panic for now or return zero.\n    panic('pickle.load not fully implemented')\n    return T{}\n}")

        # Helper for dynamic format specifiers
        self.emitter.add_function("fn py_format(val Any, spec string) string {\n    // Dynamic format specifier support is limited.\n    // V does not support runtime format string construction easily.\n    // We fallback to standard string representation.\n    return '${val}'\n}")

        # PyGenerator support
        # We need a generic struct to wrap channels for send/throw/close.
        # We use a wrapper struct for input to support throw (signaling exceptions).
        self.emitter.add_struct("""struct PyGeneratorInput {
    val Any
    is_exc bool
    exc_msg string
}""")

        self.emitter.add_struct("""struct PyGenerator[T] {
mut:
    out chan ?T
    in_ chan PyGeneratorInput
    open bool = true
}""")
        self.emitter.add_function("""fn (mut g PyGenerator[T]) next() ?T {
    if !g.open { return none }
    g.in_ <- PyGeneratorInput{val: 0} // Send dummy value
    res := <-g.out
    if res == none { g.open = false }
    return res
}""")
        self.emitter.add_function("""fn (mut g PyGenerator[T]) send(val Any) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{val: val}
    res := <-g.out
    if res == none { g.open = false }
    return res
}""")
        self.emitter.add_function("""fn (mut g PyGenerator[T]) throw(msg string) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{is_exc: true, exc_msg: msg}
    res := <-g.out
    if res == none { g.open = false }
    return res
}""")
        self.emitter.add_function("""fn (mut g PyGenerator[T]) close() {
    g.open = false
    g.in_.close()
    // g.out will be closed by the generator function loop when it detects in_ closed or panic
}""")
        # Helper for yield expression: yield val
        # py_yield(ch_out, ch_in, val)
        # Returns the value sent back via send(), or none if next() was called.
        # Panics if throw() was called.
        self.emitter.add_function("""fn py_yield[T](ch_out chan ?T, ch_in chan PyGeneratorInput, val T) Any {
    ch_out <- val
    inp := <-ch_in
    if inp.is_exc {
        panic(inp.exc_msg)
    }
    return inp.val
}""")

        # Helper for bytes formatting
        self.emitter.add_function("fn py_bytes_format(fmt []u8, args Any) []u8 {\n    // Simplistic implementation for b'%s' % b'val'\n    // Converts bytes to string, formats, and converts back.\n    // This is not efficient or correct for non-ASCII bytes but works for simple cases.\n    fmt_str := fmt.bytestr()\n    // TODO: handle args properly. V's string interpolation/formatting expects distinct args.\n    // If args is []u8, treat as string.\n    arg_str := if args is []u8 { args.bytestr() } else { '${args}' }\n    \n    // Manual substitution of %s\n    // V does not have sprintf for runtime strings easily available in core without C interop.\n    // Simple replace for %s\n    res := fmt_str.replace('%s', arg_str)\n    return res.bytes()\n}")
        # String formatting helper
        if self.used_string_format:
            self.emitter.add_import("strings")
            self.emitter.add_function("""fn py_string_format(fmt string, args ...Any) string {
    mut res := strings.new_builder(fmt.len + 16)
    mut arg_idx := 0
    mut i := 0
    for i < fmt.len {
        if fmt[i] == `%` {
            if i + 1 < fmt.len {
                if fmt[i+1] == `%` {
                    res.write_string('%')
                    i += 2
                    continue
                }
                // Parse flags
                mut j := i + 1
                mut flag_zero := false
                mut flag_minus := false
                for j < fmt.len {
                    if fmt[j] == `0` {
                        flag_zero = true
                        j++
                    } else if fmt[j] == `-` {
                        flag_minus = true
                        j++
                    } else {
                        break
                    }
                }
                // Parse width
                mut width := 0
                mut width_str := ''
                for j < fmt.len && fmt[j].is_digit() {
                    width_str += fmt[j].ascii_str()
                    j++
                }
                if width_str != '' {
                    width = width_str.int()
                }
                // Parse precision
                mut precision := -1
                if j < fmt.len && fmt[j] == `.` {
                    j++
                    mut prec_str := ''
                    for j < fmt.len && fmt[j].is_digit() {
                        prec_str += fmt[j].ascii_str()
                        j++
                    }
                    if prec_str != '' {
                        precision = prec_str.int()
                    } else {
                        precision = 0
                    }
                }
                // Parse specifier
                if j < fmt.len {
                    spec := fmt[j]
                    if arg_idx >= args.len {
                        res.write_string('%')
                        i++
                        continue
                    }
                    arg := args[arg_idx]
                    arg_idx++

                    mut s_val := ''
                    if spec == `s` {
                        s_val = '${arg}'
                    } else if spec == `d` || spec == `i` || spec == `u` {
                        // Integer formatting
                        // If arg is float, cast to int?
                        // Using V interpolation format if possible, but we need dynamic width/prec
                        // Easier to manually format
                        val_int := '${arg}'.int()
                        s_val = '${val_int}'
                        if flag_zero && width > s_val.len && !flag_minus {
                             s_val = '0'.repeat(width - s_val.len) + s_val
                        }
                    } else if spec == `f` || spec == `F` {
                        // Float formatting
                        val_f := '${arg}'.f64()
                        prec := if precision >= 0 { precision } else { 6 }
                        s_val = '${val_f:.${prec}f}'
                    } else if spec == `e` || spec == `E` {
                        val_f := '${arg}'.f64()
                        prec := if precision >= 0 { precision } else { 6 }
                        s_val = '${val_f:.${prec}e}'
                    } else if spec == `g` || spec == `G` {
                        val_f := '${arg}'.f64()
                        // V doesn't strictly support %g in interpolation same as C, but close enough
                        s_val = '${val_f}'
                    } else if spec == `x` {
                        val_int := '${arg}'.int()
                        s_val = '${val_int:x}'
                    } else if spec == `X` {
                        val_int := '${arg}'.int()
                        s_val = '${val_int:X}'
                    } else if spec == `o` {
                        val_int := '${arg}'.int()
                        s_val = '${val_int:o}'
                    } else if spec == `r` {
                        s_val = '${arg}'
                    } else if spec == `c` {
                         val_int := '${arg}'.int()
                         s_val = u8(val_int).ascii_str()
                    } else {
                        s_val = '${arg}'
                    }

                    // Apply width/align
                    if width > s_val.len {
                        pad := width - s_val.len
                        if flag_minus {
                            s_val = s_val + ' '.repeat(pad)
                        } else if !flag_zero || spec == `s` {
                             // Zero padding handled for ints above if no minus
                             // For string or default, space pad
                             s_val = ' '.repeat(pad) + s_val
                        }
                    }
                    res.write_string(s_val)
                    i = j + 1
                    continue
                }
            }
        }
        res.write_u8(fmt[i])
        i++
    }
    return res.str()
}""")

        if self.used_list_concat:
            self.emitter.add_function("""fn py_list_concat[T](lists ...[]T) []T {
    mut res := []T{}
    for l in lists {
        res << l
    }
    return res
}""")

        if self.used_dict_merge:
            self.emitter.add_function("""fn py_dict_merge[K, V](dicts ...map[K]V) map[K]V {
    mut res := map[K]V{}
    for d in dicts {
        for k, v in d {
            res[k] = v
        }
    }
    return res
}""")

        if "py_subscript" in self.used_builtins:
            self.emitter.add_function("""fn py_subscript(obj Any, idx Any) Any {
    // Dynamic subscript fallback
    if obj is string {
        if idx is int {
            mut i := idx
            if i < 0 { i += obj.len }
            if i >= 0 && i < obj.len { return obj[i].ascii_str() }
        }
    } else if obj is []u8 {
        if idx is int {
            mut i := idx
            if i < 0 { i += obj.len }
            if i >= 0 && i < obj.len { return obj[i] }
        }
    }
    panic('py_subscript: unsupported type or index')
    return false
}""")

        if "py_slice" in self.used_builtins:
            self.emitter.add_function("""fn py_slice(obj Any, lower ?Any, upper ?Any) Any {
    // Dynamic slice fallback
    if obj is string {
        mut l := 0
        if lower_val := lower {
            if lower_val is int { l = lower_val }
        }
        mut u := obj.len
        if upper_val := upper {
            if upper_val is int { u = upper_val }
        }
        if l < 0 { l += obj.len }
        if u < 0 { u += obj.len }
        if l < 0 { l = 0 }
        if u > obj.len { u = obj.len }
        if l > u { return '' }
        return obj[l..u]
    } else if obj is []u8 {
        mut l := 0
        if lower_val := lower {
            if lower_val is int { l = lower_val }
        }
        mut u := obj.len
        if upper_val := upper {
            if upper_val is int { u = upper_val }
        }
        if l < 0 { l += obj.len }
        if u < 0 { u += obj.len }
        if l < 0 { l = 0 }
        if u > obj.len { u = obj.len }
        if l > u { return []u8{} }
        return obj[l..u]
    }
    panic('py_slice: unsupported type or bounds')
    return false
}""")

        return self.emitter.emit()
