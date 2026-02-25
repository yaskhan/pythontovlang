import ast
from typing import Any, List, Optional, Dict
from py2v_transpiler.models.v_types import map_python_type_to_v
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.stdlib_map.mapper import StdLibMapper
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler

class VNodeVisitor(ast.NodeVisitor):
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
        self._zip_counter = 0 # Counter for unique variable names in zip loops
        self.used_builtins = set() # Track used built-in helpers (sorted, reversed, etc)
        self.renamed_functions = {"main": "py_main"} # Map to rename functions (e.g. main -> py_main)
        self.name_remap = {} # Temporary variable renaming (e.g. x -> it in generators)
        self._walrus_assignments: List[str] = [] # Buffer for walrus operator assignments

        self.mapper = StdLibMapper()
        self.imported_modules: Dict[str, str] = {} # alias -> module_name
        self.imported_symbols: Dict[str, str] = {} # alias -> module_name.symbol

    def _indent(self) -> str:
        return "    " * self._indent_level

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

        return self.emitter.emit()

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self._visit_function_common(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self._visit_function_common(node, is_async=True)

    def _visit_function_common(self, node: Any, is_async: bool = False) -> None:
        is_generator = False
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
             is_generator = self.coroutine_handler.is_generator(node.name)

        # Save current state
        old_output = self.output
        self.output = []
        self._indent_level = 0

        # Analyze decorators
        dec_info = self.decorator_processor.analyze(node, self.current_class)

        # Handle decorators comments (emit all for clarity)
        for decorator in node.decorator_list:
             dec_str = self.visit(decorator)
             # Avoid duplicating if in handled list?
             # Just emit comments for all decorators as metadata
             self.output.append(f"// @{dec_str}")

        is_method = self.current_class is not None
        # Ensure struct_name is always a string
        struct_name: str = self.current_class if self.current_class else ""

        args_str_list: List[str] = []
        receiver_str: str = ""
        args_names: List[str] = []

        # Special handling for unittest methods: flatten to function calls
        # We detect if we are inside a unittest class (flag set in visit_ClassDef)
        is_unittest_method = False
        if hasattr(self, 'current_class_is_unittest') and self.current_class_is_unittest:
            if node.name.startswith("test_"):
                is_unittest_method = True
                # Rename function to include class name
                func_name = f"{node.name}_{struct_name}"
                # Remove self argument and receiver
                is_method = False
                receiver_str = ""
            elif node.name in ("setUp", "tearDown"):
                 # Skip setup/teardown for now or map to V test hooks if possible
                 # V supports test_setup() but it's global per module usually?
                 # For now, comment them out
                 self.output.append(f"// {node.name} method in unittest class ignored")
                 return
            else:
                 # Helper method?
                 # Keep as function but maybe private?
                 pass

        if is_generator:
            # Inject channel argument
            # Attempt to infer type from return annotation
            yield_type = self.coroutine_handler.get_yield_type(node)
            args_str_list.append(f"ch chan {yield_type}")
            self.coroutine_handler.enter_generator("ch")

        args = node.args.args
        if is_method and args and args[0].arg == "self":
            # Handle 'self' - it becomes the receiver in V
            # UNLESS it is static
            if not dec_info.is_static:
                # fn (s Struct) method()
                if self.current_class_generics:
                    # fn (s Struct[T]) method()
                    gen_str = f"[{', '.join(self.current_class_generics)}]"
                    receiver_str = f"({args[0].arg} {struct_name}{gen_str}) "
                else:
                    receiver_str = f"({args[0].arg} {struct_name}) "

            args = args[1:] # Remove self from arguments list
        elif is_unittest_method and args and args[0].arg == "self":
             # Remove self from unittest method args
             args = args[1:]

        for arg in args:
            arg_name = arg.arg
            args_names.append(arg_name)
            # Use annotation if available for better type mapping
            if arg.annotation:
                try:
                    type_str = ast.unparse(arg.annotation)
                    arg_type = map_python_type_to_v(type_str)
                except Exception:
                    arg_type = self.type_inference.type_map.get(arg_name, "int")
            else:
                arg_type = self.type_inference.type_map.get(arg_name, "int")

            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)

        ret_type = "void"
        if not is_generator and node.returns:
             if isinstance(node.returns, ast.Name):
                  ret_type = node.returns.id
             elif isinstance(node.returns, ast.Constant) and isinstance(node.returns.value, str):
                  ret_type = node.returns.value

        if not is_unittest_method:
            func_name = node.name
            if func_name in self.renamed_functions:
                func_name = self.renamed_functions[func_name]

        # Handle cache wrapper generation
        if dec_info.cache_wrapper_needed and dec_info.implementation_name:
            wrapper_code = self.decorator_processor.generate_cache_wrapper(
                dec_info, func_name, args_str, ret_type, args_names, receiver_str
            )
            self.emitter.add_function(wrapper_code)

            # Switch to generating implementation
            func_name = dec_info.implementation_name

        if func_name == "__init__":
            # Constructor logic: make it a static factory function for now
            # fn new_Struct(...) Struct
            func_name = f"new_{struct_name}"
            receiver_str = "" # Factory is static
            ret_type = struct_name
            if self.current_class_generics:
                # new_Struct[T](...) Struct[T]
                # Wait, generic functions in V: fn foo[T](...)
                # Factory: fn new_Struct[T](...) Struct[T]
                # We need to add [T] to function name?
                # V syntax: fn new_Struct[T](...) Struct[T]
                # func_name should be new_Struct[T]
                # ret_type should be Struct[T]
                sanitized_gens = [g.lstrip('_') for g in self.current_class_generics]
                gen_str = f"[{', '.join(sanitized_gens)}]"
                func_name += gen_str
                ret_type += gen_str

            # We need to implicitly return the struct instance, but that's complex logic.
            # For now, just change the name.
        elif is_method and func_name in ("__add__", "__sub__", "__mul__", "__truediv__", "__mod__", "__lt__", "__le__", "__eq__", "__ne__"):
             # Operator overloading
             # fn (a Type) + (b Type) Type
             op_map = {
                 "__add__": "+", "__sub__": "-", "__mul__": "*", "__truediv__": "/",
                 "__mod__": "%", "__lt__": "<", "__le__": "<=", "__eq__": "==",
                 "__ne__": "!="
             }
             op = op_map.get(func_name)
             if op:
                 func_name = op
                 # In V, operator overloading syntax is: fn (a Type) + (b Type) RetType
                 # Our args_str is "b Type". We need to format it as "(b Type)".
                 # receiver_str is "(a Type) ".
                 # So: fn (a Type) + (b Type) RetType
                 # We need to ensure args_str is wrapped in parens if not already (it isn't, it's a comma list)
                 decl = f"fn {receiver_str}{op} ({args_str}) {ret_type} {{"
                 # Skip the default decl assignment below
        elif func_name in ("__str__", "__repr__"):
             # String representation
             func_name = "str"
             decl = f"fn {receiver_str}{func_name}() string {{"

        if 'decl' not in locals():
            decl = f"fn {receiver_str}{func_name}({args_str}) {ret_type} {{"
        if ret_type == "void":
             decl = f"fn {receiver_str}{func_name}({args_str}) {{"

        self.output.append(f"{decl}") # No indent for top level function
        self._indent_level += 1

        # Injected start code
        for line in dec_info.injected_start:
             self.output.append(f"{self._indent()}{line}")

        # Injected end code (defer)
        for line in dec_info.injected_end:
             self.output.append(f"{self._indent()}{line}")

        for stmt in node.body:
            self.visit(stmt)

        if is_generator:
            self.output.append(f"{self._indent()}{self.coroutine_handler.active_channel}.close()")
            self.coroutine_handler.exit_generator()

        self._indent_level -= 1
        self.output.append("}")

        # Add function to emitter
        self.emitter.add_function("\n".join(self.output))

        # Restore state
        self.output = old_output

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        # Map Python class to V struct
        struct_name = node.name
        self.current_class = struct_name
        self.current_class_generics = []
        self.current_class_bases = []
        self.current_class_is_unittest = False

        # Handle decorators
        decorators = []
        for decorator in node.decorator_list:
            dec_str = self.visit(decorator)
            decorators.append(f"// @{dec_str}")

        # Extract fields from __init__ or class body annotations (simplified)
        fields = []

        is_enum = False
        is_int_enum = False
        is_unittest = False

        # Handle inheritance (bases)
        for base in node.bases:
            # Handle Enum
            if isinstance(base, ast.Name):
                if base.id == "Enum":
                    is_enum = True
                elif base.id == "IntEnum":
                    is_int_enum = True
                elif base.id == "TestCase":
                     # Check if it's likely unittest.TestCase
                     # Or check if base is Attribute unittest.TestCase
                     is_unittest = True

            elif isinstance(base, ast.Attribute):
                # Check for unittest.TestCase
                val = self.visit(base)
                if val == "unittest.TestCase" or (isinstance(base.value, ast.Name) and base.value.id == "unittest" and base.attr == "TestCase"):
                     is_unittest = True

            # Handle Generic[T]
            if isinstance(base, ast.Subscript):
                base_name = ""
                if isinstance(base.value, ast.Name):
                    base_name = base.value.id
                elif isinstance(base.value, ast.Attribute):
                    base_name = base.value.attr

                if base_name == "Generic":
                    # Extract type vars: Generic[T, U]
                    if isinstance(base.slice, ast.Tuple):
                        for elt in base.slice.elts:
                            if isinstance(elt, ast.Name):
                                self.current_class_generics.append(elt.id)
                    elif isinstance(base.slice, ast.Name):
                        self.current_class_generics.append(base.slice.id)
                    # Don't add Generic to fields
                    continue
                else:
                    # Regular generic base: Parent[T]
                    # Add to fields as embedded struct
                    type_str = ast.unparse(base)
                    v_type = map_python_type_to_v(type_str)
                    fields.append(f"    {v_type}")
                    self.current_class_bases.append(base_name)

            elif isinstance(base, ast.Name):
                if base.id != "Generic":
                    fields.append(f"    {base.id}")
                    self.current_class_bases.append(base.id)
            elif isinstance(base, ast.Attribute):
                val = self.visit(base)
                fields.append(f"    {val}")
                self.current_class_bases.append(base.attr)

        methods = []

        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods.append(stmt)
            elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                # Class attribute with annotation -> struct field
                field_name = stmt.target.id
                field_type = "int" # default
                if stmt.annotation:
                    try:
                        type_str = ast.unparse(stmt.annotation)
                        field_type = map_python_type_to_v(type_str)
                    except Exception:
                        if isinstance(stmt.annotation, ast.Name):
                            field_type = stmt.annotation.id
                fields.append(f"    {field_name} {field_type}")

        if is_unittest:
             self.current_class_is_unittest = True
             # Do NOT emit struct for unittest class, just methods
             for method in methods:
                 self.visit(method)
        else:
            struct_def = ""
            if decorators:
                struct_def += "\n".join(decorators) + "\n"

            if is_int_enum:
                # Transpile to V enum
                enum_fields = []
                for stmt in node.body:
                    if isinstance(stmt, ast.Assign):
                        for target in stmt.targets:
                            if isinstance(target, ast.Name):
                                # snake_case conversion for member
                                member_name = target.id.lower()
                                value = self.visit(stmt.value)
                                enum_fields.append(f"    {member_name} = {value}")

                struct_def += f"enum {struct_name} {{\n" + "\n".join(enum_fields) + "\n}"
                self.emitter.add_struct(struct_def)
                # Skip method generation for simple enums for now
                return

            generics_str = ""
            if self.current_class_generics:
                # Sanitize: _T -> T
                sanitized = [g.lstrip('_') for g in self.current_class_generics]
                self.current_class_generics = sanitized
                generics_str = f"[{', '.join(sanitized)}]"

            struct_def += f"struct {struct_name}{generics_str} {{\n" + "\n".join(fields) + "\n}"
            self.emitter.add_struct(struct_def)

            # Visit methods to generate them as functions
            for method in methods:
                self.visit(method)

        self.current_class = None
        self.current_class_generics = []
        self.current_class_bases = []
        self.current_class_is_unittest = False

    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            module_name = alias.name
            as_name = alias.asname if alias.asname else module_name
            self.imported_modules[as_name] = module_name

            # Add V imports via mapper
            v_imports = self.mapper.get_imports(module_name)
            if v_imports is not None:
                for imp in v_imports:
                    self.emitter.add_import(imp)
            else:
                # If not mapped (None), import as is
                self.emitter.add_import(module_name)

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        if node.module:
            module_name = node.module

            # Add V imports
            v_imports = self.mapper.get_imports(module_name)
            if v_imports is not None:
                for imp in v_imports:
                    self.emitter.add_import(imp)
            # Else? For ImportFrom, we don't necessarily import the module if not mapped,
            # unless we need symbols from it. Python `from x import y` imports y.
            # If not mapped, we might need `import x` or `import x.y`.
            # Existing logic didn't handle `else` case for ImportFrom explicitly
            # except implicitly assuming `y` would be used.

            for alias in node.names:
                name = alias.name
                as_name = alias.asname if alias.asname else name
                self.imported_symbols[as_name] = f"{module_name}.{name}"

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        target = self.visit(node.target)
        value = self.visit(node.value)
        op_map = {
            ast.Add: "+=", ast.Sub: "-=", ast.Mult: "*=", ast.Div: "/=",
            ast.Mod: "%="
        }
        # V supports +=, -=, *=, /=, %=
        # V does not support **= (must use math.pow or similar, which is not AugAssign compatible directly)
        op_str = op_map.get(type(node.op))
        if op_str:
             self.output.append(f"{self._indent()}{target} {op_str} {value}")
        else:
             self.output.append(f"{self._indent()}// Unsupported AugAssign operator: {type(node.op)}")

    def visit_Assign(self, node: ast.Assign) -> None:
        target = node.targets[0]
        lhs = ""
        if isinstance(target, ast.Name):
            lhs = target.id

            # Check for TypeVar: T = TypeVar("T", int, str)
            if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == "TypeVar":
                # Check args for constraints
                # args[0] is name
                constraints = []
                for arg in node.value.args[1:]:
                    if isinstance(arg, ast.Name):
                        constraints.append(map_python_type_to_v(arg.id))
                    elif isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                        constraints.append(map_python_type_to_v(arg.value))

                # Check keyword bound
                for kw in node.value.keywords:
                    if kw.arg == "bound":
                        # bound=Union[int, str] or bound=int
                        # We can use ast.unparse and map
                         try:
                             bound_str = ast.unparse(kw.value)
                             mapped = map_python_type_to_v(bound_str)
                             # If mapped is "int | string", we use it
                             constraints.append(mapped)
                         except:
                             pass

                if constraints:
                    # Emit sum type
                    # Sanitize lhs?
                    sanitized_lhs = lhs.lstrip('_')
                    # If multiple constraints, join with |
                    # But mapped bound might already be a union string "A | B"
                    # We need to be careful not to create "A | B | C" if they are distinct

                    final_type = " | ".join(constraints)
                    self.emitter.add_struct(f"type {sanitized_lhs} = {final_type}")
                return

            # Check for type alias: MyType = int or MyType = OtherType
            if self.in_main and isinstance(node.value, ast.Name):
                # Basic heuristic: if it looks like a type assignment
                # Allow primitive types and potentially other class names (capitalized)
                # But be careful not to catch variable assignment.
                # In Python, `x = y` is var assignment. `Type = int` is type alias.
                # We can restrict to known primitives OR if the LHS is capitalized (heuristic for Type)
                # and RHS is a Name.
                if node.value.id in ("int", "str", "bool", "float"):
                    self.emitter.add_struct(f"type {lhs} = {node.value.id}")
                    return
                elif lhs[0].isupper() and node.value.id[0].isupper():
                     # Heuristic: MyType = OtherType
                     self.emitter.add_struct(f"type {lhs} = {node.value.id}")
                     return
        elif isinstance(target, ast.Attribute):
            # obj.attr = value
            lhs = f"{self.visit(target.value)}.{target.attr}"
        elif isinstance(target, ast.Subscript):
            # list[index] = value
            lhs = self.visit(target)

        if isinstance(node.value, ast.ListComp):
            self.visit_ListComp(node.value, target_var=lhs)
        else:
            rhs = self.visit(node.value)
            self.output.append(f"{self._indent()}{lhs} := {rhs}")

    def visit_ListComp(self, node: ast.ListComp, target_var: Optional[str] = None) -> None:
        if not target_var:
            self.output.append(f"{self._indent()}// List comprehension expression not supported inline yet")
            return

        self.output.append(f"{self._indent()}mut {target_var} := []int{{}}")

        gen = node.generators[0] # Handle first generator

        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name) and gen.iter.func.id == "zip":
             args = gen.iter.args
             if len(args) == 2:
                 self._zip_counter += 1
                 zip_id = self._zip_counter

                 it1 = self.visit(args[0])
                 it2 = self.visit(args[1])

                 var_it1 = f"_zip_it1_{zip_id}"
                 var_it2 = f"_zip_it2_{zip_id}"
                 var_i = f"_i_{zip_id}"
                 var_v1 = f"_v1_{zip_id}"
                 var_v2 = f"_v2_{zip_id}"

                 self.output.append(f"{self._indent()}{var_it1} := {it1}")
                 self.output.append(f"{self._indent()}{var_it2} := {it2}")

                 self.output.append(f"{self._indent()}for {var_i}, {var_v1} in {var_it1} {{")
                 self._indent_level += 1

                 self.output.append(f"{self._indent()}if {var_i} >= {var_it2}.len {{ break }}")
                 self.output.append(f"{self._indent()}{var_v2} := {var_it2}[{var_i}]")

                 if isinstance(gen.target, ast.Tuple) and len(gen.target.elts) == 2:
                     t1 = self.visit(gen.target.elts[0])
                     t2 = self.visit(gen.target.elts[1])
                     self.output.append(f"{self._indent()}{t1} := {var_v1}")
                     self.output.append(f"{self._indent()}{t2} := {var_v2}")
                 else:
                     target = self.visit(gen.target)
                     self.output.append(f"{self._indent()}{target} := [{var_v1}, {var_v2}]")

                 for if_expr in gen.ifs:
                    cond = self.visit(if_expr)
                    self.output.append(f"{self._indent()}if {cond} {{")
                    self._indent_level += 1

                 elt = self.visit(node.elt)
                 self.output.append(f"{self._indent()}{target_var} << {elt}")

                 for _ in gen.ifs:
                    self._indent_level -= 1
                    self.output.append(f"{self._indent()}}}")

                 self._indent_level -= 1
                 self.output.append(f"{self._indent()}}}")
                 return

        target = self.visit(gen.target)
        iter_expr = self.visit(gen.iter)

        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name):
             if gen.iter.func.id == "range":
                 args = gen.iter.args
                 if len(args) == 3:
                     # range(start, stop, step) -> C-style for loop
                     # We need to manually construct the loop here because `visit_ListComp` expects `iter_expr`
                     # But `iter_expr` is usually an iterable.
                     # However, `visit_ListComp` uses `for {target} in {iter_expr} {`.
                     # We can trick it by setting iter_expr to handle the step? No, `in` syntax doesn't support step.
                     # We must emit a C-style loop: `for i := start; i < stop; i += step {`
                     # But `visit_ListComp` hardcodes `for ... in ...`.
                     # We need to restructure `visit_ListComp` to handle this or modify the output manually.
                     # Let's override the loop generation for range with step.

                     start = self.visit(args[0])
                     stop = self.visit(args[1])
                     step = self.visit(args[2])

                     is_negative_step = False
                     if isinstance(args[2], ast.UnaryOp) and isinstance(args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(args[2], ast.Constant) and isinstance(args[2].value, (int, float)) and args[2].value < 0:
                         is_negative_step = True

                     op = ">" if is_negative_step else "<"

                     # We skip the standard `visit_ListComp` loop generation logic for this specific generator
                     # and manually implement it.

                     self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
                     self._indent_level += 1

                     for if_expr in gen.ifs:
                        cond = self.visit(if_expr)
                        self.output.append(f"{self._indent()}if {cond} {{")
                        self._indent_level += 1

                     elt = self.visit(node.elt)
                     self.output.append(f"{self._indent()}{target_var} << {elt}")

                     for _ in gen.ifs:
                        self._indent_level -= 1
                        self.output.append(f"{self._indent()}}}")

                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")
                     return

                 start = "0"
                 stop = "0"
                 if len(args) == 1:
                      stop = self.visit(args[0])
                 elif len(args) == 2:
                      start = self.visit(args[0])
                      stop = self.visit(args[1])
                 iter_expr = f"{start}..{stop}"
             elif gen.iter.func.id == "enumerate":
                 if gen.iter.args:
                     iter_expr = self.visit(gen.iter.args[0])
                     # Handle target for enumerate: for i, v in items
                     if isinstance(gen.target, ast.Tuple):
                         # visit_Tuple returns [i, v], we need i, v
                         if target.startswith("[") and target.endswith("]"):
                             target = target[1:-1]
                     else:
                         self.output.append(f"{self._indent()}// TODO: handle enumerate with single target variable")

        self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
        self._indent_level += 1

        for if_expr in gen.ifs:
            cond = self.visit(if_expr)
            self.output.append(f"{self._indent()}if {cond} {{")
            self._indent_level += 1

        elt = self.visit(node.elt)
        self.output.append(f"{self._indent()}{target_var} << {elt}")

        for _ in gen.ifs:
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Dict(self, node: ast.Dict) -> str:
        if not node.keys:
            # Empty dict
            return "map[string]int{}" # Default fallback

        pairs = []
        for k, v in zip(node.keys, node.values):
            if k:
                key_str = self.visit(k)
                val_str = self.visit(v)
                pairs.append(f"{key_str}: {val_str}")
        return f"map[string]int{{{', '.join(pairs)}}}"

    def visit_Set(self, node: ast.Set) -> str:
        # {1, 2} -> map[int]bool{1: true, 2: true}
        # Simplified assumption that elements are ints
        elements = []
        for elt in node.elts:
            val = self.visit(elt)
            elements.append(f"{val}: true")

        return f"map[int]bool{{{', '.join(elements)}}}"

    def visit_List(self, node: ast.List) -> str:
        elements = [str(self.visit(elt)) for elt in node.elts]
        if not elements:
             return "[]int{}" # Placeholder for empty list
        return f"[{', '.join(elements)}]"

    def visit_Tuple(self, node: ast.Tuple) -> str:
        # Translate Tuple (a, b) to Array [a, b]
        elements = [str(self.visit(elt)) for elt in node.elts]
        return f"[{', '.join(elements)}]"

    def visit_Lambda(self, node: ast.Lambda) -> str:
        # lambda args: expr -> fn (args) { return expr }
        args_str_list = []
        for arg in node.args.args:
            arg_name = arg.arg
            arg_type = "int" # Default type for now
            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)
        body = self.visit(node.body)

        # Assuming return type is inferred or int for now
        # V anonymous functions: fn (a int) int { return a + 1 }
        return f"fn ({args_str}) int {{ return {body} }}"

    def visit_Yield(self, node: ast.Yield) -> str:
        if self.coroutine_handler.active_channel:
             val = self.visit(node.value) if node.value else "0"
             return f"{self.coroutine_handler.active_channel} <- {val}"
        # yield expr -> /* yield expr */
        val = ""
        if node.value:
            val = self.visit(node.value)
        return f"/* yield {val} */"

    def visit_YieldFrom(self, node: ast.YieldFrom) -> Optional[str]:
        if self.coroutine_handler.active_channel:
             val = self.visit(node.value)
             self.output.append(f"{self._indent()}for v in {val} {{")
             self._indent_level += 1
             self.output.append(f"{self._indent()}{self.coroutine_handler.active_channel} <- v")
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")
             return None

        val = self.visit(node.value)
        return f"/* yield from {val} */"

    def visit_Await(self, node: ast.Await) -> str:
        # await foo() -> // await foo()
        val = self.visit(node.value)
        return f"/* await */ {val}"

    def visit_Assert(self, node: ast.Assert) -> None:
        test = self.visit(node.test)
        self.output.append(f"{self._indent()}assert {test}")

    def visit_Global(self, node: ast.Global) -> None:
        names = ", ".join(node.names)
        self.output.append(f"{self._indent()}// global {names}")

    def visit_Nonlocal(self, node: ast.Nonlocal) -> None:
        names = ", ".join(node.names)
        self.output.append(f"{self._indent()}// nonlocal {names}")

    def visit_Delete(self, node: ast.Delete) -> None:
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                # del l[i] -> l.delete(i)
                value = self.visit(target.value)
                index = self.visit(target.slice)
                self.output.append(f"{self._indent()}{value}.delete({index})")
            elif isinstance(target, ast.Name):
                self.output.append(f"{self._indent()}/* del {target.id} */")
            elif isinstance(target, ast.Attribute):
                value = self.visit(target.value)
                self.output.append(f"{self._indent()}/* del {value}.{target.attr} */")
            else:
                self.output.append(f"{self._indent()}// del statement with unsupported target type")

    def visit_Return(self, node: ast.Return) -> None:
        if node.value:
            val = self.visit(node.value)
            self.output.append(f"{self._indent()}return {val}")
        else:
            self.output.append(f"{self._indent()}return")

    def visit_Expr(self, node: ast.Expr) -> None:
        val = self.visit(node.value)
        if val:
            self.output.append(f"{self._indent()}{val}")

    def visit_Call(self, node: ast.Call) -> str:
        # Check if we can resolve the call via mapper
        args = []
        for arg in node.args:
            val = self.visit(arg)
            if val is not None:
                args.append(str(val))
            else:
                args.append("/* unknown */")

        func_node = node.func
        module_name = None
        func_name = None

        # Resolve qualified name if possible (e.g. datetime.datetime.now or os.path.join)
        qualified_name_parts: List[str] = []
        curr = func_node
        while isinstance(curr, ast.Attribute):
            qualified_name_parts.insert(0, curr.attr)
            curr = curr.value

        if isinstance(curr, ast.Name):
            qualified_name_parts.insert(0, curr.id)
            # Check if root is a known module
            root_name = qualified_name_parts[0]
            if root_name in self.imported_modules:
                 module_name = self.imported_modules[root_name]
                 # construct func_name from rest
                 func_name = ".".join(qualified_name_parts[1:])
            elif root_name == "os" and len(qualified_name_parts) > 1 and qualified_name_parts[1] == "path":
                 # Special case for os.path
                 module_name = "os"
                 func_name = ".".join(qualified_name_parts[1:])

        if not module_name and isinstance(func_node, ast.Attribute):
            # obj.method() fallback
            if isinstance(func_node.value, ast.Name) and func_node.value.id in self.imported_modules:
                module_name = self.imported_modules[func_node.value.id]
                func_name = func_node.attr

        if not module_name and isinstance(func_node, ast.Name):
            # func()
            if func_node.id in self.imported_symbols:
                # from mod import func
                full_name = self.imported_symbols[func_node.id]
                parts = full_name.split(".")
                module_name = parts[0]
                func_name = parts[1]
            elif func_node.id == "open":
                module_name = "os" # synthetic
                func_name = "open"
            elif func_node.id in ("hasattr", "getattr", "setattr", "type", "super"):
                 module_name = "builtins" # synthetic
                 func_name = func_node.id

        if module_name == "os" and func_name == "open":
             # Handle open() -> os.open()
             self.emitter.add_import("os")
             if len(args) >= 1:
                 # In V: os.open(path) returns ?File, so we unwrap it.
                 # Assuming read mode for simplicity as mapped from open(path)
                 return f"os.open({args[0]}) or {{ panic(err) }}"

        if module_name == "builtins":
            if func_name == "hasattr":
                 # hasattr(obj, 'attr')
                 # Best effort: comments
                 return f"/* hasattr({', '.join(args)}) - reflection not fully supported */ false"
            elif func_name == "getattr":
                 if len(args) >= 2:
                      # check if args[1] is string literal
                      # args[1] is already visited code, e.g. "'attr'"
                      attr_name = args[1]
                      if attr_name.startswith("'") and attr_name.endswith("'"):
                           return f"{args[0]}.{attr_name[1:-1]}"
                 return f"/* getattr({', '.join(args)}) - dynamic access not supported */"
            elif func_name == "setattr":
                 if len(args) >= 3:
                      attr_name = args[1]
                      if attr_name.startswith("'") and attr_name.endswith("'"):
                           return f"{args[0]}.{attr_name[1:-1]} = {args[2]}"
                 return f"/* setattr({', '.join(args)}) - dynamic setting not supported */"
            elif func_name == "type":
                if len(args) >= 1:
                    return f"typeof({args[0]}).name"
            elif func_name == "super":
                 pass

        if module_name and func_name:
            mapped = self.mapper.get_mapping(module_name, func_name, args)
            if mapped:
                return mapped

        # Try finding os.path.X by concatenating if attribute access
        if isinstance(func_node, ast.Attribute) and isinstance(func_node.value, ast.Attribute):
             # os.path.join -> value is os.path, attr is join
             # Check if os.path is module
             pass

        # Handle threading.Lock.acquire/release -> lock/unlock
        # Heuristic: if method name is acquire/release and receiver is unknown or mapped to sync.Mutex (hard to know type here)
        # We can just map acquire->lock, release->unlock generally if threading is imported?
        # Or check if receiver name suggests lock?
        # Safe approach: if threading is used, and method is acquire/release, map it.
        # But this might conflict with other classes.
        # Let's check mapped type? We don't have robust type inference for variables yet.
        # Just map it for now if threading is imported.
        if "threading" in self.imported_modules.values() and isinstance(func_node, ast.Attribute):
             if func_node.attr == "acquire":
                 receiver = self.visit(func_node.value)
                 return f"{receiver}.lock()"
             elif func_node.attr == "release":
                 receiver = self.visit(func_node.value)
                 return f"{receiver}.unlock()"

        # Handle super().method()
        if isinstance(func_node, ast.Attribute) and isinstance(func_node.value, ast.Call) and \
           isinstance(func_node.value.func, ast.Name) and func_node.value.func.id == "super":
            # super().method(...)
            method_name = func_node.attr
            if self.current_class_bases:
                parent = self.current_class_bases[0]
                return f"self.{parent}.{method_name}({', '.join(args)})"
            else:
                 return f"/* super().{method_name} call without known parent */"

        # Handle unittest assertions
        # Strictly check for self.assertX if possible to avoid regressions
        # We check if receiver is "self"
        is_self_assertion = False
        if isinstance(func_node, ast.Attribute) and func_node.attr.startswith("assert"):
             if isinstance(func_node.value, ast.Name) and func_node.value.id == "self":
                 is_self_assertion = True

        if is_self_assertion and isinstance(func_node, ast.Attribute):
             assertion = func_node.attr
             if assertion == "assertEqual" and len(args) == 2:
                  return f"assert {args[0]} == {args[1]}"
             elif assertion == "assertNotEqual" and len(args) == 2:
                  return f"assert {args[0]} != {args[1]}"
             elif assertion == "assertTrue" and len(args) == 1:
                  return f"assert {args[0]}"
             elif assertion == "assertFalse" and len(args) == 1:
                  return f"assert !({args[0]})"
             elif assertion == "assertIn" and len(args) == 2:
                  return f"assert {args[0]} in {args[1]}"
             elif assertion == "assertNotIn" and len(args) == 2:
                  return f"assert {args[0]} !in {args[1]}"
             elif assertion == "assertIsNone" and len(args) == 1:
                  return f"assert {args[0]} == none"
             elif assertion == "assertIsNotNone" and len(args) == 1:
                  return f"assert {args[0]} != none"
             elif assertion == "assertIs" and len(args) == 2:
                   return f"assert {args[0]} == {args[1]}" # Approx
             elif assertion == "assertIsNot" and len(args) == 2:
                   return f"assert {args[0]} != {args[1]}" # Approx

        # unittest.main()
        if module_name == "unittest" and func_name == "main":
             return "// unittest.main() ignored"

        # Fallback to existing logic
        func_name_str = self.visit(node.func)
        if func_name_str in self.renamed_functions:
            func_name_str = self.renamed_functions[func_name_str]

        # Handle builtins handled by old logic (print, sorted, etc)
        # Note: 'open', 'hasattr' are handled above or fall through if not matched.
        # But wait, open is not in existing logic.

        if isinstance(func_node, ast.Attribute) and func_node.attr == "clear" and not module_name:
             obj = self.visit(func_node.value)
             return f"/* {obj}.clear() */ {obj} = {{}}"

        if func_name_str == "sorted":
            self.used_builtins.add("sorted")
            return f"py_sorted({', '.join(args)})"
        elif func_name_str == "reversed":
            self.used_builtins.add("reversed")
            return f"py_reversed({', '.join(args)})"
        elif func_name_str == "map":
            if len(args) == 2:
                func = args[0]
                iterable = args[1]
                return f"{iterable}.map({func}(it))"
        elif func_name_str == "filter":
            if len(args) == 2:
                func = args[0]
                iterable = args[1]
                if func == "None" or func == "none":
                    return f"{iterable}.filter(it)"
                return f"{iterable}.filter({func}(it))"
        elif func_name_str == "any" or func_name_str == "all":
            if len(node.args) == 1:
                arg = node.args[0]
                if isinstance(arg, ast.GeneratorExp):
                    # any(expr for target in iter) -> iter.any(expr_with_it)
                    gen = arg.generators[0]
                    target = gen.target
                    iter_expr = self.visit(gen.iter)

                    if isinstance(target, ast.Name):
                        # Map target name to 'it'
                        self.name_remap[target.id] = "it"
                        elt = self.visit(arg.elt)
                        del self.name_remap[target.id]
                        return f"{iter_expr}.{func_name_str}({elt})"
                else:
                    # any(iterable) -> iterable.any(it)
                    val = self.visit(arg)
                    return f"{val}.{func_name_str}(it)"

        elif func_name_str == "isinstance":
            if len(args) == 2:
                obj = args[0]
                types = args[1]
                if types.startswith("[") and types.endswith("]"):
                     return f"/* isinstance({obj}, {types}) - multi-type check not supported */ false"
                return f"{obj} is {types}"

        elif func_name_str == "input":
            self.emitter.add_import("os")
            if args:
                return f"os.input({args[0]})"
            return "os.input('')"

        elif func_name_str == "print":
            sep = " "
            end = "\\n"

            for keyword in node.keywords:
                if keyword.arg == "sep":
                    if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                        sep = keyword.value.value
                elif keyword.arg == "end":
                    if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                        end = keyword.value.value
                        if end == "\n":
                            end = "\\n"

            parts = []
            for arg in node.args:
                val = self.visit(arg)
                val_str = str(val)
                if val_str.startswith("'") and val_str.endswith("'"):
                    parts.append(val_str[1:-1])
                else:
                    parts.append(f"${{{val_str}}}")

            joined_content = sep.join(parts)

            if end == "\\n":
                return f"println('{joined_content}')"
            elif end == "":
                return f"print('{joined_content}')"
            else:
                return f"print('{joined_content}{end}')"

        return f"{func_name_str}({', '.join(args)})"

    def visit_Attribute(self, node: ast.Attribute) -> str:
        # Check if this is a mapped constant (e.g. math.pi)
        if isinstance(node.value, ast.Name) and node.value.id in self.imported_modules:
             module_name = self.imported_modules[node.value.id]
             const_name = node.attr
             mapped = self.mapper.get_constant_mapping(module_name, const_name)
             if mapped:
                 return mapped

        if node.attr == "__class__":
             obj = self.visit(node.value)
             return f"typeof({obj})"

        obj = self.visit(node.value)
        return f"{obj}.{node.attr}"

    def visit_Subscript(self, node: ast.Subscript) -> str:
        value = self.visit(node.value)

        if isinstance(node.slice, ast.Slice):
            lower = self.visit(node.slice.lower) if node.slice.lower else ""
            upper = self.visit(node.slice.upper) if node.slice.upper else ""
            return f"{value}[{lower}..{upper}]"
        else:
            index = self.visit(node.slice)
            return f"{value}[{index}]"

    def visit_JoinedStr(self, node: ast.JoinedStr) -> str:
        parts = []
        for value in node.values:
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                val = value.value
                val = val.replace('\\', '\\\\')
                val = val.replace("'", "\\'")
                val = val.replace('\n', '\\n')
                val = val.replace('\r', '\\r')
                val = val.replace('\t', '\\t')
                parts.append(val)
            else:
                parts.append(str(self.visit(value)))

        return f"'{''.join(parts)}'"

    def visit_FormattedValue(self, node: ast.FormattedValue) -> str:
        val = self.visit(node.value)
        if isinstance(node.format_spec, ast.JoinedStr):
            spec_parts = []
            for v in node.format_spec.values:
                if isinstance(v, ast.Constant):
                    spec_parts.append(str(v.value))
                else:
                    # Best effort for dynamic format specs
                    spec_parts.append(str(self.visit(v)))
            spec = "".join(spec_parts)
            return f"${{{val}:{spec}}}"
        return f"${{{val}}}"

    def visit_BinOp(self, node: ast.BinOp) -> str:
        left = self.visit(node.left)
        right = self.visit(node.right)
        op_map = {
            ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/",
            ast.Mod: "%", ast.Pow: "**"
        }
        op_str = op_map.get(type(node.op), "?")
        return f"{left} {op_str} {right}"

    def visit_If(self, node: ast.If) -> None:
        # Check for if __name__ == "__main__":
        if isinstance(node.test, ast.Compare):
            if (isinstance(node.test.left, ast.Name) and node.test.left.id == "__name__" and
                len(node.test.comparators) == 1 and isinstance(node.test.comparators[0], ast.Constant) and
                node.test.comparators[0].value == "__main__"):
                self.output.append(f"{self._indent()}// if __name__ == '__main__':")
                for stmt in node.body:
                    self.visit(stmt)
                return

        # Check for walrus operator
        self._walrus_assignments = []
        test_expr = self.visit(node.test)

        if self._walrus_assignments:
             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")
             self._walrus_assignments = []

        self.output.append(f"{self._indent()}if {test_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1

        if node.orelse:
            if len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If):
                # elif case
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                self.visit(node.orelse[0])
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
            else:
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                for stmt in node.orelse:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
        else:
            self.output.append(f"{self._indent()}}}")

    def visit_While(self, node: ast.While) -> None:
        self._walrus_assignments = []
        test_expr = self.visit(node.test)

        if self._walrus_assignments:
             # Found walrus! Transform loop.
             self.output.append(f"{self._indent()}for {{")
             self._indent_level += 1

             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")

             self.output.append(f"{self._indent()}if !({test_expr}) {{ break }}")
             self._walrus_assignments = []

             for stmt in node.body:
                 self.visit(stmt)

             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")
        else:
             # Normal while
             self.output.append(f"{self._indent()}for {test_expr} {{")
             self._indent_level += 1
             for stmt in node.body:
                 self.visit(stmt)
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")

    def visit_NamedExpr(self, node: ast.NamedExpr) -> str:
        # (target := value)
        target = node.target.id
        value = self.visit(node.value)
        self._walrus_assignments.append(f"{target} := {value}")
        return target

    def visit_For(self, node: ast.For) -> None:
        # Check if iterating over generator
        iter_node = node.iter
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name):
            if self.coroutine_handler.is_generator(iter_node.func.id):
                 # Generate setup
                 ch_name = self.coroutine_handler.get_temp_channel_name()
                 yield_type = self.coroutine_handler.get_generator_type(iter_node.func.id)
                 self.output.append(f"{self._indent()}{ch_name} := chan {yield_type}{{cap: 0}}")

                 # Call spawn
                 # Construct args
                 # node.iter is Call(func, args, keywords)
                 # We need to inject ch_name as first arg
                 func_name = iter_node.func.id
                 # self.visit(node.iter.args) ?
                 args = [ch_name] + [str(self.visit(a)) for a in iter_node.args]
                 call_str = f"spawn {func_name}({', '.join(args)})"
                 self.output.append(f"{self._indent()}{call_str}")

                 # Now loop over channel
                 target = self.visit(node.target)
                 self.output.append(f"{self._indent()}for {target} in {ch_name} {{")
                 self._indent_level += 1
                 for stmt in node.body:
                     self.visit(stmt)
                 self._indent_level -= 1
                 self.output.append(f"{self._indent()}}}")
                 return

        # Zip handling
        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name) and node.iter.func.id == "zip":
            args = node.iter.args
            if len(args) == 2:
                self._zip_counter += 1
                zip_id = self._zip_counter
                it1 = self.visit(args[0])
                it2 = self.visit(args[1])
                var_it1 = f"_zip_it1_{zip_id}"
                var_it2 = f"_zip_it2_{zip_id}"
                var_i = f"_i_{zip_id}"
                var_v1 = f"_v1_{zip_id}"
                var_v2 = f"_v2_{zip_id}"
                self.output.append(f"{self._indent()}{var_it1} := {it1}")
                self.output.append(f"{self._indent()}{var_it2} := {it2}")
                self.output.append(f"{self._indent()}for {var_i}, {var_v1} in {var_it1} {{")
                self._indent_level += 1
                self.output.append(f"{self._indent()}if {var_i} >= {var_it2}.len {{ break }}")
                self.output.append(f"{self._indent()}{var_v2} := {var_it2}[{var_i}]")
                if isinstance(node.target, ast.Tuple) and len(node.target.elts) == 2:
                    t1 = self.visit(node.target.elts[0])
                    t2 = self.visit(node.target.elts[1])
                    self.output.append(f"{self._indent()}{t1} := {var_v1}")
                    self.output.append(f"{self._indent()}{t2} := {var_v2}")
                else:
                    target = self.visit(node.target)
                    self.output.append(f"{self._indent()}{target} := [{var_v1}, {var_v2}]")
                for stmt in node.body:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
                return

        target = self.visit(node.target)
        iter_expr = self.visit(node.iter)

        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name):
             if node.iter.func.id == "range":
                 args = node.iter.args
                 if len(args) == 3:
                     start = self.visit(args[0])
                     stop = self.visit(args[1])
                     step = self.visit(args[2])
                     is_negative_step = False
                     if isinstance(args[2], ast.UnaryOp) and isinstance(args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(args[2], ast.Constant) and isinstance(args[2].value, (int, float)) and args[2].value < 0:
                         is_negative_step = True
                     op = ">" if is_negative_step else "<"
                     self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
                     self._indent_level += 1
                     for stmt in node.body:
                         self.visit(stmt)
                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")
                     return
                 start = "0"
                 stop = "0"
                 if len(args) == 1:
                      stop = self.visit(args[0])
                 elif len(args) == 2:
                      start = self.visit(args[0])
                      stop = self.visit(args[1])
                 iter_expr = f"{start}..{stop}"
             elif node.iter.func.id == "enumerate":
                 if node.iter.args:
                     iter_expr = self.visit(node.iter.args[0])
                     if isinstance(node.target, ast.Tuple):
                         if target.startswith("[") and target.endswith("]"):
                             target = target[1:-1]
                     else:
                         self.output.append(f"{self._indent()}// TODO: handle enumerate with single target variable")

        self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Try(self, node: ast.Try) -> None:
        self.output.append(f"{self._indent()}// try {{")
        for stmt in node.body:
            self.visit(stmt)
        self.output.append(f"{self._indent()}// }} except {{")
        for handler in node.handlers:
            self.output.append(f"{self._indent()}// Handler: {handler.type}")
            self.output.append(f"{self._indent()}// ... exception handling logic ...")
        if node.finalbody:
             self.output.append(f"{self._indent()}// }} finally {{")
             self.output.append(f"{self._indent()}defer {{")
             self._indent_level += 1
             for stmt in node.finalbody:
                 self.visit(stmt)
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")

    def visit_With(self, node: ast.With) -> None:
        for item in node.items:
            context_expr = self.visit(item.context_expr)
            if item.optional_vars:
                var = self.visit(item.optional_vars)
                self.output.append(f"{self._indent()}{var} := {context_expr}")
                self.output.append(f"{self._indent()}defer {{ {var}.close() }}")
            else:
                self.output.append(f"{self._indent()}_ := {context_expr}")
        for stmt in node.body:
            self.visit(stmt)

    def visit_Compare(self, node: ast.Compare) -> str:
        left = self.visit(node.left)
        ops = {
            ast.Eq: "==", ast.NotEq: "!=", ast.Lt: "<", ast.LtE: "<=",
            ast.Gt: ">", ast.GtE: ">=", ast.Is: "==", ast.IsNot: "!=",
            ast.In: "in", ast.NotIn: "!in"
        }
        result = [str(left)]
        for op, comparator in zip(node.ops, node.comparators):
             op_str = ops.get(type(op), "?")
             comp_val = self.visit(comparator)

             if isinstance(op, ast.Is) and comp_val == "none":
                 op_str = "=="
             elif isinstance(op, ast.IsNot) and comp_val == "none":
                 op_str = "!="

             result.append(f"{op_str} {comp_val}")
        return " ".join(result)

    def visit_BoolOp(self, node: ast.BoolOp) -> str:
        op_map = {ast.And: "&&", ast.Or: "||"}
        op_str = op_map.get(type(node.op), "and")
        values = [str(self.visit(val)) for val in node.values]
        return f" {op_str} ".join(values)

    def visit_UnaryOp(self, node: ast.UnaryOp) -> str:
        operand = self.visit(node.operand)
        op_map = {ast.Not: "!", ast.UAdd: "+", ast.USub: "-"}
        op_str = op_map.get(type(node.op), "?")
        return f"{op_str}{operand}"

    def visit_Break(self, node: ast.Break) -> None:
        self.output.append(f"{self._indent()}break")

    def visit_Continue(self, node: ast.Continue) -> None:
        self.output.append(f"{self._indent()}continue")

    def visit_Name(self, node: ast.Name) -> str:
        if node.id in self.name_remap:
            return self.name_remap[node.id]
        return node.id

    def visit_Constant(self, node: ast.Constant) -> str:
        val = node.value
        if isinstance(val, str):
            return f"'{val}'"
        elif isinstance(val, bool):
            return str(val).lower()
        elif val is None:
            return "none"
        return str(val)

    def visit_Match(self, node: "ast.Match") -> None:
        subject = self.visit(node.subject)
        self.output.append(f"{self._indent()}match {subject} {{")
        self._indent_level += 1
        for case in node.cases:
            self._visit_match_case(case)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def _visit_match_case(self, node: "ast.match_case") -> None:
        pattern_str = self._translate_pattern(node.pattern)
        if node.guard:
            self.output.append(f"{self._indent()}// Guard condition '{self.visit(node.guard)}' ignored in match case")
        self.output.append(f"{self._indent()}{pattern_str} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def _translate_pattern(self, pattern: ast.AST) -> str:
        if isinstance(pattern, ast.MatchValue):
            return str(self.visit(pattern.value))
        elif isinstance(pattern, ast.MatchSingleton):
            return str(pattern.value).lower()
        elif isinstance(pattern, ast.MatchOr):
            parts = [self._translate_pattern(p) for p in pattern.patterns]
            return ", ".join(parts)
        elif isinstance(pattern, ast.MatchAs):
             if pattern.name is None:
                 return "else"
             else:
                 return f"else /* bound to {pattern.name} */"
        return "else"

    def generic_visit(self, node: ast.AST) -> Any:
        return super().generic_visit(node)
