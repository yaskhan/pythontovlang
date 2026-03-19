import ast
from typing import Any, List, Optional, Dict, Set
from .base import TranslatorBase

class ModuleMixin(TranslatorBase):
    def visit_Module(self, node: ast.Module) -> str:
        # Pre-scan for __all__ and symbols
        self.module_all = None
        for stmt in node.body:
            # Track imported symbols for re-export
            if isinstance(stmt, ast.Import):
                for alias in stmt.names:
                    self.defined_top_level_symbols.add(alias.asname if alias.asname else alias.name)
            elif isinstance(stmt, ast.ImportFrom):
                for alias in stmt.names:
                    self.defined_top_level_symbols.add(alias.asname if alias.asname else alias.name)

            if isinstance(stmt, ast.Assign):
                for target in stmt.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        if isinstance(stmt.value, (ast.List, ast.Tuple)):
                            self.module_all = []
                            for elt in stmt.value.elts:
                                if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                                    self.module_all.append(elt.value)
                        break

        self.emitter.module_name = self.current_module_name
        self.global_vars = set()
        for subnode in ast.walk(node):
            if isinstance(subnode, ast.Global):
                self.global_vars.update(subnode.names)

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
            # Skip __all__ assignment in output
            if isinstance(stmt, ast.Assign):
                is_all = False
                for target in stmt.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        is_all = True
                        break
                if is_all:
                    continue

            # Check if statement is top-level expression or assignment
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Import, ast.ImportFrom)):
                self.in_main = False
                # Line comment for Functions and Classes is handled inside their visitors
                self.visit(stmt)
                self.in_main = True
            else:
                # This is part of main body
                # We need to capture the output of this statement
                # But visit returns None and appends to self.output
                # So we need to manage self.output

                # Clear output buffer
                self.output = []
                # For top-level expressions and assignments, we add the line comment here
                if getattr(self.config, 'source_mapping', False):
                    self.output.append(f"// @line: {self._get_source_info(stmt)}")
                self.visit(stmt)
                # Append buffer to main
                for line in self.output:
                    # Remove indentation if added by _indent() for main body
                    # Because generator adds indentation for main()
                    self.emitter.add_main_statement(line.strip())
                self.output = []

        # Post-scan validation for __all__
        if self.module_all is not None:
            # Check for undefined symbols in __all__
            for name in self.module_all:
                if name not in self.defined_top_level_symbols:
                    self.warnings.append(f"Symbol '{name}' listed in __all__ but not defined in module")

            # Check for public symbols missing from __all__ if strict mode enabled
            config = getattr(self, 'config', None)
            if config and getattr(config, 'strict_export_mode', False):
                for name in self.defined_top_level_symbols:
                    if name != "__all__" and not name.startswith('_') and name not in self.module_all:
                        self.warnings.append(f"Public symbol '{name}' not listed in __all__")

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
            self.emitter.add_helper_function("\n".join(lines))

        if "sorted" in self.used_builtins:
            self.emitter.add_helper_function(
                "fn py_sorted[T](a []T) []T {\n    mut b := a.clone()\n    b.sort()\n    return b\n}"
            )
        if "reversed" in self.used_builtins:
            self.emitter.add_helper_function(
                "fn py_reversed[T](a []T) []T {\n    mut b := a.clone()\n    b.reverse()\n    return b\n}"
            )
            
        if "py_is_identical" in self.used_builtins:
             self.emitter.add_helper_function("fn py_is_identical[T, U](a T, b U) bool {\n    return voidptr(&a) == voidptr(&b)\n}")

        if "py_repeat" in self.used_builtins:
             self.emitter.add_helper_function("fn py_repeat[T](val T, n int) []T {\n    return []T{len: n, init: val}\n}")

        if "py_repeat_list" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_repeat_list[T](a []T, n int) []T {
    mut res := []T{cap: a.len * n}
    for _ in 0 .. n {
        res << a
    }
    return res
}""")

        if "round" in self.used_builtins:
            self.emitter.add_helper_function(
                "fn py_round(number f64, ndigits int) f64 {\n    p := math.pow(10, f64(ndigits))\n    return math.round(number * p) / p\n}"
            )

        if self.used_complex:
             self.emitter.add_helper_struct("struct PyComplex {\n    re f64\n    im f64\n}")
             self.emitter.add_helper_function("fn py_complex(re f64, im f64) PyComplex {\n    return PyComplex{re: re, im: im}\n}")
             self.emitter.add_helper_function("fn (a PyComplex) + (b PyComplex) PyComplex {\n    return PyComplex{re: a.re + b.re, im: a.im + b.im}\n}")
             self.emitter.add_helper_function("fn (a PyComplex) - (b PyComplex) PyComplex {\n    return PyComplex{re: a.re - b.re, im: a.im - b.im}\n}")
             self.emitter.add_helper_function("fn (a PyComplex) * (b PyComplex) PyComplex {\n    return PyComplex{re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re}\n}")
             self.emitter.add_helper_function("fn (a PyComplex) / (b PyComplex) PyComplex {\n    denom := b.re * b.re + b.im * b.im\n    return PyComplex{re: (a.re * b.re + a.im * b.im) / denom, im: (a.im * b.re - a.re * b.im) / denom}\n}")
             self.emitter.add_helper_function("fn (z PyComplex) str() string {\n    sign := if z.im >= 0 { '+' } else { '-' }\n    im_abs := if z.im >= 0 { z.im } else { -z.im }\n    return '(${z.re}${sign}${im_abs}j)'\n}")

        # Simple check for tempfile usage. `imported_modules` values are module names.
        # But we also need to check if we actually used the helpers, which are returned by mapper.
        # The mapper returns strings like "py_temp_dir()".
        # We can scan the emitted output for usage, but `self.output` is cleared.
        # However, `self.emitter` holds the full code.
        # Let's just check if `tempfile` was imported.
        if "tempfile" in self.imported_modules.values():
             self.emitter.add_helper_import("os")
             self.emitter.add_helper_struct("struct PyTempDir {\n    path string\n}")
             self.emitter.add_helper_function("fn (d PyTempDir) close() {\n    os.rmdir_all(d.path) or {}\n}")
             self.emitter.add_helper_function("fn py_temp_dir() PyTempDir {\n    p := os.mkdir_temp('') or { panic(err) }\n    return PyTempDir{path: p}\n}")
             self.emitter.add_helper_function("fn py_named_temp_file() os.File {\n    f, _ := os.create_temp('') or { panic(err) }\n    return f\n}")

        if "logging" in self.imported_modules.values():
             self.emitter.add_helper_import("log")
             self.emitter.add_helper_function("fn py_get_logger(name string) log.Log {\n    mut l := log.Log{}\n    l.set_level(.info)\n    return l\n}")

        if "argparse" in self.imported_modules.values():
             self.emitter.add_helper_import("os")
             self.emitter.add_helper_struct("struct PyArgDef {\n    name string\n}")
             self.emitter.add_helper_struct("struct PyArgumentParser {\n    mut:\n    definitions []PyArgDef\n}")
             self.emitter.add_helper_function("fn py_argparse_new() PyArgumentParser {\n    return PyArgumentParser{}\n}")
             self.emitter.add_helper_function("fn (mut p PyArgumentParser) add_argument(name string) {\n    p.definitions << PyArgDef{name: name}\n}")
             self.emitter.add_helper_function("fn (mut p PyArgumentParser) parse_args() map[string]string {\n    mut args := map[string]string{}\n    // Placeholder manual parsing logic\n    for i := 0; i < os.args.len; i++ {\n        arg := os.args[i]\n        if arg.starts_with('--') {\n            key := arg[2..]\n            val := if i + 1 < os.args.len { os.args[i+1] } else { '' }\n            args[key] = val\n        }\n    }\n    return args\n}")

        used_modules_from_symbols = set()
        for sym in self.imported_symbols.values():
            parts = sym.split('.')
            for i in range(1, len(parts)):
                used_modules_from_symbols.add('.'.join(parts[:i]))

        pathlib_used = "pathlib" in self.imported_modules.values()
        if not pathlib_used:
             pathlib_used = "pathlib" in used_modules_from_symbols

        # Check for collections usage
        collections_used = "collections" in self.imported_modules.values()
        if not collections_used:
             collections_used = "collections" in used_modules_from_symbols

        if collections_used:
             self.emitter.add_helper_function("fn py_counter[T](a []T) map[T]int {\n    mut m := map[T]int{}\n    for x in a {\n        m[x]++\n    }\n    return m\n}")

        itertools_used = "itertools" in self.imported_modules.values()
        if not itertools_used:
             itertools_used = "itertools" in used_modules_from_symbols

        if itertools_used:
             # py_chain: variadic, generic, flattens arrays
             # Note: V generics with variadic args might be tricky.
             # fn py_chain[T](args ...[]T) []T
             self.emitter.add_helper_function("fn py_chain[T](args ...[]T) []T {\n    mut res := []T{}\n    for arg in args {\n        res << arg\n    }\n    return res\n}")

             # py_repeat: returns array initialized with value
             self.emitter.add_helper_function("fn py_repeat[T](val T, n int) []T {\n    return []T{len: n, init: val}\n}")

             # py_count: iterator struct
             self.emitter.add_helper_struct("struct PyCountIterator {\nmut:\n    val int\n    step int\n}")
             self.emitter.add_helper_function("fn (mut i PyCountIterator) next() ?int {\n    val := i.val\n    i.val += i.step\n    return val\n}")
             self.emitter.add_helper_function("fn py_count(start int, step int) PyCountIterator {\n    return PyCountIterator{val: start, step: step}\n}")

             # py_cycle: iterator struct
             # Cycle needs to store the array and current index
             self.emitter.add_helper_struct("struct PyCycleIterator[T] {\n    data []T\nmut:\n    idx int\n}")
             self.emitter.add_helper_function("fn (mut i PyCycleIterator[T]) next() ?T {\n    if i.data.len == 0 { return none }\n    val := i.data[i.idx]\n    i.idx = (i.idx + 1) % i.data.len\n    return val\n}")
             self.emitter.add_helper_function("fn py_cycle[T](data []T) PyCycleIterator[T] {\n    return PyCycleIterator[T]{data: data}\n}")

        functools_used = "functools" in self.imported_modules.values()
        if not functools_used:
             functools_used = "functools" in used_modules_from_symbols

        if functools_used:
             # py_reduce helper
             self.emitter.add_helper_function("fn py_reduce[T](op fn (acc T, x T) T, iter []T) T {\n    if iter.len == 0 { panic('reduce() of empty sequence with no initial value') }\n    mut acc := iter[0]\n    for i in 1..iter.len {\n        acc = op(acc, iter[i])\n    }\n    return acc\n}")

        operator_used = "operator" in self.imported_modules.values()
        if not operator_used:
             operator_used = "operator" in used_modules_from_symbols

        if operator_used:
             self.emitter.add_helper_function("fn py_op_add[T](a T, b T) T { return a + b }")
             self.emitter.add_helper_function("fn py_op_sub[T](a T, b T) T { return a - b }")
             self.emitter.add_helper_function("fn py_op_mul[T](a T, b T) T { return a * b }")
             self.emitter.add_helper_function("fn py_op_div[T](a T, b T) T { return a / b }")
             self.emitter.add_helper_function("fn py_op_mod[T](a T, b T) T { return a % b }")
             self.emitter.add_helper_function("fn py_op_eq[T](a T, b T) bool { return a == b }")
             self.emitter.add_helper_function("fn py_op_ne[T](a T, b T) bool { return a != b }")
             self.emitter.add_helper_function("fn py_op_lt[T](a T, b T) bool { return a < b }")
             self.emitter.add_helper_function("fn py_op_le[T](a T, b T) bool { return a <= b }")
             self.emitter.add_helper_function("fn py_op_gt[T](a T, b T) bool { return a > b }")
             self.emitter.add_helper_function("fn py_op_ge[T](a T, b T) bool { return a >= b }")
             self.emitter.add_helper_function("fn py_op_not(a bool) bool { return !a }")
             self.emitter.add_helper_function("fn py_op_and(a bool, b bool) bool { return a && b }")
             self.emitter.add_helper_function("fn py_op_or(a bool, b bool) bool { return a || b }")
             # xor in V is ^ for ints, but logic xor? (a != b)
             self.emitter.add_helper_function("fn py_op_xor[T](a T, b T) T { return a ^ b }")

        threading_used = "threading" in self.imported_modules.values()
        if not threading_used:
             threading_used = "threading" in used_modules_from_symbols

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

            self.emitter.add_helper_struct("//##LLM@@ PyThread implementation is a placeholder. Please implement proper threading using V's 'spawn' and thread handles.\nstruct PyThread {\nmut:\n    handle thread int\n    // task fn() // V function types in structs?\n}")
            self.emitter.add_helper_function("fn (mut t PyThread) start() {\n    // Implementation requires generic task storage or closures\n    println('PyThread.start() called. Note: V spawns immediately on `spawn`. This requires manual adjustment.')\n}")
            self.emitter.add_helper_function("fn (mut t PyThread) join() {\n    t.handle.wait()\n}")

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
             socket_used = "socket" in used_modules_from_symbols

        if socket_used:
            # Constants
            self.emitter.add_helper_import("net")
            self.emitter.add_helper_struct("const py_AF_INET = 2")
            self.emitter.add_helper_struct("const py_SOCK_STREAM = 1")

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
            self.emitter.add_helper_struct("struct PySocket {\nmut:\n    listener ?net.TcpListener\n    conn ?net.TcpConn\n    is_server bool\n    bound_addr string\n    bound_port int\n}")

            # py_socket_new
            self.emitter.add_helper_function("fn py_socket_new(af int, type_ int) PySocket {\n    return PySocket{}\n}")

            # bind
            # args: address tuple (host, port)
            # In V, we just store it. Listen happens on listen().
            self.emitter.add_helper_function("fn (mut s PySocket) bind(addr []string) {\n    // Expecting addr to be [host, port_str] or similar from transpiled tuple\n    // But tuple transpilation maps to array of strings? Or array of mixed?\n    // If tuple (str, int) -> struct? or array of sumtype?\n    // Assuming simplistic transpilation of tuple to array of strings/anys.\n    // Here we stub it.\n    s.bound_addr = addr[0]\n    // s.bound_port = addr[1].int() // pseudo\n}")

            # listen
            # s.listen(backlog)
            # In V: listener := net.listen_tcp(.ip, '$addr:$port') or { panic(err) }
            self.emitter.add_helper_function("fn (mut s PySocket) listen(backlog int) {\n    s.is_server = true\n    l := net.listen_tcp(.ip6, '${s.bound_addr}:${s.bound_port}') or { panic(err) }\n    s.listener = l\n}")

            # accept
            # conn, addr = s.accept()
            # Returns (conn, addr)
            # V: l.accept() returns TcpConn.
            # We need to return (PySocket, addr_tuple)
            # But V functions return multi values.
            # We return (PySocket, []string)
            self.emitter.add_helper_function("fn (mut s PySocket) accept() (PySocket, []string) {\n    if mut l := s.listener {\n        new_conn := l.accept() or { panic(err) }\n        // addr := new_conn.peer_addr()?\n        return PySocket{conn: new_conn}, ['127.0.0.1', '0']\n    }\n    panic('accept on non-listener')\n}")

            # connect
            # s.connect((host, port))
            self.emitter.add_helper_function("fn (mut s PySocket) connect(addr []string) {\n    c := net.dial_tcp('${addr[0]}:${addr[1]}') or { panic(err) }\n    s.conn = c\n}")

            # send (bytes) -> write
            self.emitter.add_helper_function("fn (mut s PySocket) send(data []u8) int {\n    if mut c := s.conn {\n        c.write(data) or { panic(err) }\n        return data.len\n    }\n    return 0\n}")

            # recv (bufsize) -> read
            self.emitter.add_helper_function("fn (mut s PySocket) recv(bufsize int) []u8 {\n    if mut c := s.conn {\n        mut buf := []u8{len: bufsize}\n        n := c.read(mut buf) or { 0 }\n        return buf[..n]\n    }\n    return []u8{}\n}")

            # close
            self.emitter.add_helper_function("fn (mut s PySocket) close() {\n    if mut c := s.conn {\n        c.close() or {}\n    }\n    if mut l := s.listener {\n        l.close() or {}\n    }\n}")

        if pathlib_used:
             # struct PyPath { path string }
             self.emitter.add_helper_import("os")
             self.emitter.add_helper_struct("struct PyPath {\n    path string\n}")

             # py_path_new
             self.emitter.add_helper_function("fn py_path_new(p string) PyPath {\n    return PyPath{path: p}\n}")

             # operator /
             self.emitter.add_helper_function("fn (p PyPath) / (other string) PyPath {\n    return PyPath{path: os.join_path(p.path, other)}\n}")

             # exists
             self.emitter.add_helper_function("fn (p PyPath) exists() bool {\n    return os.exists(p.path)\n}")

             # is_dir
             self.emitter.add_helper_function("fn (p PyPath) is_dir() bool {\n    return os.is_dir(p.path)\n}")

             # is_file
             self.emitter.add_helper_function("fn (p PyPath) is_file() bool {\n    return os.is_file(p.path)\n}")

             # read_text
             self.emitter.add_helper_function("fn (p PyPath) read_text() string {\n    return os.read_file(p.path) or { panic(err) }\n}")

             # write_text
             self.emitter.add_helper_function("fn (p PyPath) write_text(text string) {\n    os.write_file(p.path, text) or { panic(err) }\n}")

             # str
             self.emitter.add_helper_function("fn (p PyPath) str() string {\n    return p.path\n}")

        http_used = "urllib.request" in self.imported_modules.values() or "http.client" in self.imported_modules.values()
        if not http_used:
             http_used = "urllib.request" in used_modules_from_symbols or "http.client" in used_modules_from_symbols

        if http_used:
             # PyHttpResponse
             self.emitter.add_helper_import("net.http")
             self.emitter.add_helper_struct("struct PyHttpResponse {\n    body string\n}")
             self.emitter.add_helper_function("fn (r PyHttpResponse) read() string {\n    return r.body\n}")

             # py_urlopen
             self.emitter.add_helper_function("fn py_urlopen(url string) PyHttpResponse {\n    resp := http.get(url) or { panic(err) }\n    return PyHttpResponse{body: resp.body}\n}")

             # PyHttpConnection (mock/wrapper for http.client)
             self.emitter.add_helper_struct("struct PyHttpConnection {\n    host string\nmut:\n    resp PyHttpResponse\n}")
             self.emitter.add_helper_function("fn py_http_connection(host string) PyHttpConnection {\n    return PyHttpConnection{host: host}\n}")
             self.emitter.add_helper_function("fn (mut c PyHttpConnection) request(method string, path string) {\n    url := 'http://${c.host}${path}'\n    resp := http.fetch(http.FetchConfig{url: url, method: method}) or { panic(err) }\n    c.resp = PyHttpResponse{body: resp.body}\n}")
             self.emitter.add_helper_function("fn (c PyHttpConnection) getresponse() PyHttpResponse {\n    return c.resp\n}")

        csv_used = "csv" in self.imported_modules.values()
        if not csv_used:
             csv_used = "csv" in used_modules_from_symbols

        if csv_used:
             # PyCsvReader wrapper
             # Wraps csv.Reader. Needs iterator protocol.
             # V csv.Reader.read() returns ?[]string.
             self.emitter.add_helper_import("encoding.csv")
             self.emitter.add_helper_struct("struct PyCsvReader {\nmut:\n    reader csv.Reader\n}")
             # Helper to init. f is os.File which implements io.Reader (in V).
             # But csv.new_reader expects io.Reader. os.File works.
             # Note: V's io.Reader interface requires `read(mut []u8) !int`.
             # os.File has it.
             self.emitter.add_helper_function("fn py_csv_reader(f os.File) PyCsvReader {\n    return PyCsvReader{reader: csv.new_reader(f)}\n}")

             # next method for iteration
             # V loops `for x in iter` call `next() ?T`.
             self.emitter.add_helper_function("fn (mut r PyCsvReader) next() ?[]string {\n    res := r.reader.read() or { return none }\n    return res\n}")

             # PyCsvWriter wrapper
             self.emitter.add_helper_struct("struct PyCsvWriter {\nmut:\n    writer csv.Writer\n}")
             self.emitter.add_helper_function("fn py_csv_writer(f os.File) PyCsvWriter {\n    return PyCsvWriter{writer: csv.new_writer(f)}\n}")

             # writerow
             self.emitter.add_helper_function("fn (mut w PyCsvWriter) writerow(row []string) {\n    w.writer.write(row) or { panic(err) }\n}")

        sqlite3_used = "sqlite3" in self.imported_modules.values()
        if not sqlite3_used:
             sqlite3_used = "sqlite3" in used_modules_from_symbols

        if sqlite3_used:
             # PySqliteConnection wrapping sqlite.DB
             self.emitter.add_helper_import("db.sqlite")
             self.emitter.add_helper_struct("struct PySqliteConnection {\n    db sqlite.DB\n}")
             # py_sqlite_connect
             self.emitter.add_helper_function("fn py_sqlite_connect(path string) PySqliteConnection {\n    db := sqlite.connect(path) or { panic(err) }\n    return PySqliteConnection{db: db}\n}")

             # PySqliteCursor
             # Needs ref to DB. V structs pass by value unless ref or handle. sqlite.DB is a handle (voidptr C.sqlite3).
             # It also needs to store results of last query for fetchall.
             self.emitter.add_helper_struct("struct PySqliteCursor {\n    db sqlite.DB\nmut:\n    rows []sqlite.Row\n}")

             # cursor() method
             self.emitter.add_helper_function("fn (c PySqliteConnection) cursor() PySqliteCursor {\n    return PySqliteCursor{db: c.db}\n}")

             # execute(sql)
             self.emitter.add_helper_function("fn (mut c PySqliteCursor) execute(sql string) {\n    // Basic execute. For SELECT, store rows.\n    // V sqlite exec returns []Row.\n    // Note: sqlite.exec takes (query string) ![]Row\n    rows := c.db.exec(sql) or { panic(err) }\n    c.rows = rows\n}")

             # fetchall()
             self.emitter.add_helper_function("fn (c PySqliteCursor) fetchall() []sqlite.Row {\n    return c.rows\n}")

             # commit()
             self.emitter.add_helper_function("fn (c PySqliteConnection) commit() {\n    // V sqlite usually auto-commits or simple exec. No explicit commit API exposed in vlib/db/sqlite usually unless raw?\n    // But 'commit' is SQL. c.db.exec('COMMIT')?\n    // Let's execute COMMIT.\n    c.db.exec('COMMIT') or {}\n}")

             # close()
             self.emitter.add_helper_function("fn (c PySqliteConnection) close() {\n    c.db.close() or {}\n}")

        subprocess_used = "subprocess" in self.imported_modules.values()
        if not subprocess_used:
             subprocess_used = "subprocess" in used_modules_from_symbols

        if subprocess_used:
             # PyCompletedProcess
             self.emitter.add_helper_import("os")
             self.emitter.add_helper_struct("struct PyCompletedProcess {\n    returncode int\n    stdout string\n    stderr string\n}")

             # py_subprocess_run(args []string) PyCompletedProcess
             # Using os.new_process for security (avoiding shell injection)
             self.emitter.add_helper_function("fn py_subprocess_run(args []string) PyCompletedProcess {\n    if args.len == 0 { return PyCompletedProcess{returncode: 1, stdout: '', stderr: 'No arguments'} }\n    mut p := os.new_process(args[0])\n    p.set_args(args[1..])\n    p.set_redirect_stdio()\n    p.run()\n    p.wait()\n    res := PyCompletedProcess{returncode: p.code, stdout: p.stdout_slurp(), stderr: p.stderr_slurp()}\n    p.close()\n    return res\n}")

             # py_subprocess_call(args []string) int
             self.emitter.add_helper_function("fn py_subprocess_call(args []string) int {\n    if args.len == 0 { return 1 }\n    mut p := os.new_process(args[0])\n    p.set_args(args[1..])\n    p.run()\n    p.wait()\n    code := p.code\n    p.close()\n    return code\n}")

        platform_used = "platform" in self.imported_modules.values()
        if not platform_used:
             platform_used = "platform" in used_modules_from_symbols

        if platform_used:
             # py_platform_machine
             self.emitter.add_helper_function("fn py_platform_machine() string {\n    return os.uname().machine\n}")

        hashlib_used = "hashlib" in self.imported_modules.values()
        if not hashlib_used:
             hashlib_used = "hashlib" in used_modules_from_symbols

        if hashlib_used:
             # PyHashSha256
             self.emitter.add_helper_import("crypto.sha256")
             self.emitter.add_helper_import("crypto.md5")
             self.emitter.add_helper_struct("struct PyHashSha256 {\nmut:\n    data []u8\n}")
             self.emitter.add_helper_function("fn py_hash_sha256(data []u8) PyHashSha256 {\n    return PyHashSha256{data: data}\n}")
             self.emitter.add_helper_function("fn (mut h PyHashSha256) update(data []u8) {\n    h.data << data\n}")
             self.emitter.add_helper_function("fn (h PyHashSha256) digest() []u8 {\n    return sha256.sum(h.data)\n}")
             self.emitter.add_helper_function("fn (h PyHashSha256) hexdigest() string {\n    return sha256.hexhash(h.data)\n}")

             # PyHashMd5
             self.emitter.add_helper_struct("struct PyHashMd5 {\nmut:\n    data []u8\n}")
             self.emitter.add_helper_function("fn py_hash_md5(data []u8) PyHashMd5 {\n    return PyHashMd5{data: data}\n}")
             self.emitter.add_helper_function("fn (mut h PyHashMd5) update(data []u8) {\n    h.data << data\n}")
             self.emitter.add_helper_function("fn (h PyHashMd5) digest() []u8 {\n    return md5.sum(h.data)\n}")
             self.emitter.add_helper_function("fn (h PyHashMd5) hexdigest() string {\n    return md5.hexhash(h.data)\n}")

        urllib_parse_used = "urllib.parse" in self.imported_modules.values()
        if not urllib_parse_used:
             urllib_parse_used = "urllib.parse" in used_modules_from_symbols

        if urllib_parse_used:
             # py_urllib_unquote
             self.emitter.add_helper_import("net.urllib")
             self.emitter.add_helper_function("fn py_urllib_unquote(s string) string {\n    return urllib.query_unescape(s) or { s }\n}")

             # py_urlencode
             # V's Values.add takes (key, val). urlencode takes map.
             self.emitter.add_helper_function("fn py_urlencode(params map[string]string) string {\n    mut v := urllib.new_values(map[string][]string{})\n    for key, val in params {\n        v.add(key, val)\n    }\n    return v.encode()\n}")

             # py_urlparse
             # Returns urllib.URL.
             # Python urlparse returns ParseResult (named tuple).
             # V's urllib.parse returns !URL.
             # We can just return urllib.URL, but Python attributes might differ.
             # Python: scheme, netloc, path, params, query, fragment
             # V: scheme, host, path, raw_query, fragment. (netloc ~= host, query ~= raw_query).
             # We might need a wrapper struct if we want exact field names, but for now let's return URL.
             # Helper handles the result unwrapping.
             self.emitter.add_helper_function("fn py_urlparse(url string) urllib.URL {\n    return urllib.parse(url) or { urllib.URL{} }\n}")

        zlib_used = "zlib" in self.imported_modules.values()
        if not zlib_used:
             zlib_used = "zlib" in used_modules_from_symbols

        if zlib_used:
             # py_zlib_compress
             self.emitter.add_helper_import("compress.zlib")
             self.emitter.add_helper_function("fn py_zlib_compress(data []u8) []u8 {\n    return zlib.compress(data) or { panic(err) }\n}")
             # py_zlib_decompress
             self.emitter.add_helper_function("fn py_zlib_decompress(data []u8) []u8 {\n    return zlib.decompress(data) or { panic(err) }\n}")

        gzip_used = "gzip" in self.imported_modules.values()
        if not gzip_used:
             gzip_used = "gzip" in used_modules_from_symbols

        if gzip_used:
             # py_gzip_compress
             self.emitter.add_helper_function("fn py_gzip_compress(data []u8) []u8 {\n    return gzip.compress(data) or { panic(err) }\n}")
             # py_gzip_decompress
             self.emitter.add_helper_function("fn py_gzip_decompress(data []u8) []u8 {\n    return gzip.decompress(data) or { panic(err) }\n}")

        copy_used = "copy" in self.imported_modules.values()
        if not copy_used:
             copy_used = "copy" in used_modules_from_symbols

        if copy_used:
             # py_copy
             # Generic shallow copy using V's compile-time reflection
             self.emitter.add_helper_function("fn py_copy[T](x T) T {\n    $if T is $Array {\n        return x.clone()\n    } $else $if T is $Map {\n        return x.clone()\n    } $else {\n        return x\n    }\n}")
             # py_deepcopy
             # Alias to py_copy (shallow copy via clone) as best effort for now.
             # In V, clone() for collections usually copies elements.
             # If elements are structs, they are copied (value).
             # If elements are pointers, pointers are copied (shallow).
             # True deep copy requires recursion.
             self.emitter.add_helper_function("fn py_deepcopy[T](x T) T {\n    // Note: This uses .clone() which may not be a full deep copy for nested references\n    $if T is $Array {\n        return x.clone()\n    } $else $if T is $Map {\n        return x.clone()\n    } $else {\n        return x\n    }\n}")

        struct_used = "struct" in self.imported_modules.values()
        if not struct_used:
             struct_used = "struct" in used_modules_from_symbols

        if struct_used:
             # Stub for generic pack/unpack
             self.emitter.add_helper_import("encoding.binary")
             llm_comment = "//##LLM@@ 'struct' module methods are stubbed because dynamic format strings are not supported natively in V. Please implement specific packing/unpacking."
             self.emitter.add_helper_function(f"{llm_comment}\nfn py_struct_pack(fmt string, args ...Any) []u8 {{\n    panic('struct.pack with dynamic format not implemented')\n    return []u8{{}}\n}}")
             # Return []Any is hard in V without sum types for all primitives. For now, stub return empty.
             self.emitter.add_helper_function(f"{llm_comment}\nfn py_struct_unpack(fmt string, data []u8) []int {{\n    panic('struct.unpack with dynamic format not implemented')\n    return []int{{}}\n}}")
             self.emitter.add_helper_function(f"{llm_comment}\nfn py_struct_calcsize(fmt string) int {{\n    panic('struct.calcsize with dynamic format not implemented')\n    return 0\n}}")

             # Little Endian Helpers
             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_I_le(val u32) []u8 {\n    mut buf := []u8{len: 4}\n    binary.little_endian_put_u32(mut buf, val)\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_I_le(buf []u8) u32 {\n    return binary.little_endian_u32(buf)\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_i_le(val int) []u8 {\n    mut buf := []u8{len: 4}\n    binary.little_endian_put_u32(mut buf, u32(val))\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_i_le(buf []u8) int {\n    return int(binary.little_endian_u32(buf))\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_H_le(val u16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.little_endian_put_u16(mut buf, val)\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_H_le(buf []u8) u16 {\n    return binary.little_endian_u16(buf)\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_h_le(val i16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.little_endian_put_u16(mut buf, u16(val))\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_h_le(buf []u8) i16 {\n    return i16(binary.little_endian_u16(buf))\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_Q_le(val u64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.little_endian_put_u64(mut buf, val)\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_Q_le(buf []u8) u64 {\n    return binary.little_endian_u64(buf)\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_q_le(val i64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.little_endian_put_u64(mut buf, u64(val))\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_q_le(buf []u8) i64 {\n    return i64(binary.little_endian_u64(buf))\n}")

             # Big Endian Helpers
             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_I_be(val u32) []u8 {\n    mut buf := []u8{len: 4}\n    binary.big_endian_put_u32(mut buf, val)\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_I_be(buf []u8) u32 {\n    return binary.big_endian_u32(buf)\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_i_be(val int) []u8 {\n    mut buf := []u8{len: 4}\n    binary.big_endian_put_u32(mut buf, u32(val))\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_i_be(buf []u8) int {\n    return int(binary.big_endian_u32(buf))\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_H_be(val u16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.big_endian_put_u16(mut buf, val)\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_H_be(buf []u8) u16 {\n    return binary.big_endian_u16(buf)\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_h_be(val i16) []u8 {\n    mut buf := []u8{len: 2}\n    binary.big_endian_put_u16(mut buf, u16(val))\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_h_be(buf []u8) i16 {\n    return i16(binary.big_endian_u16(buf))\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_Q_be(val u64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.big_endian_put_u64(mut buf, val)\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_Q_be(buf []u8) u64 {\n    return binary.big_endian_u64(buf)\n}")

             self.emitter.add_helper_import("encoding.binary")
             self.emitter.add_helper_function("fn py_struct_pack_q_be(val i64) []u8 {\n    mut buf := []u8{len: 8}\n    binary.big_endian_put_u64(mut buf, u64(val))\n    return buf\n}")
             self.emitter.add_helper_function("fn py_struct_unpack_q_be(buf []u8) i64 {\n    return i64(binary.big_endian_u64(buf))\n}")


        array_used = "array" in self.imported_modules.values()
        if not array_used:
             array_used = "array" in used_modules_from_symbols

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
             self.emitter.add_helper_function("fn py_array[T](code string, init []T) []T {\n    // Best effort: ignoring typecode validation, returning typed array directly\n    return init\n}")

        fractions_used = "fractions" in self.imported_modules.values()
        if not fractions_used:
             fractions_used = "fractions" in used_modules_from_symbols

        if fractions_used:
             # py_fraction helper for single argument (int, float, string)
             # V fractions.fraction(n, d) is for two ints.
             # fractions.from_f64(f) exists.
             # Parsing string requires custom logic or libc atof?
             # For now, simplistic implementation for int/float/string
             self.emitter.add_helper_import("math.fractions")
             self.emitter.add_helper_function("//##LLM@@ `py_fraction` parsing from string is incomplete. Please implement logic to parse string fractions into math.fractions.Fraction.\nfn py_fraction(val Any) fractions.Fraction {\n    $if val is $int {\n        return fractions.fraction(i64(val), 1)\n    } $else $if val is $float {\n        return fractions.from_f64(f64(val))\n    } $else $if val is string {\n        // Simplistic string parsing not implemented in helper yet\n        return fractions.fraction(0, 1)\n    }\n    return fractions.fraction(0, 1)\n}")

        statistics_used = "statistics" in self.imported_modules.values()
        if not statistics_used:
             statistics_used = "statistics" in used_modules_from_symbols

        if statistics_used:
             # py_statistics_mean
             self.emitter.add_helper_import("math")
             self.emitter.add_helper_function("fn py_statistics_mean[T](data []T) f64 {\n    mut sum := f64(0)\n    for x in data {\n        sum += f64(x)\n    }\n    if data.len == 0 { return 0.0 }\n    return sum / f64(data.len)\n}")

             # py_statistics_median
             self.emitter.add_helper_function("fn py_statistics_median[T](data []T) f64 {\n    if data.len == 0 { return 0.0 }\n    mut sorted_data := data.clone()\n    sorted_data.sort()\n    mid := sorted_data.len / 2\n    if sorted_data.len % 2 == 1 {\n        return f64(sorted_data[mid])\n    }\n    return (f64(sorted_data[mid-1]) + f64(sorted_data[mid])) / 2.0\n}")

             # py_statistics_mode
             self.emitter.add_helper_function("fn py_statistics_mode[T](data []T) T {\n    if data.len == 0 { panic('statistics.mode on empty data') }\n    mut counts := map[T]int{}\n    for x in data {\n        counts[x]++\n    }\n    mut max_count := 0\n    mut mode_val := data[0]\n    for val, count in counts {\n        if count > max_count {\n            max_count = count\n            mode_val = val\n        }\n    }\n    return mode_val\n}")

             # py_statistics_variance
             self.emitter.add_helper_function("fn py_statistics_variance[T](data []T) f64 {\n    if data.len < 2 { panic('statistics.variance requires at least two data points') }\n    m := py_statistics_mean(data)\n    mut sum_sq_diff := f64(0)\n    for x in data {\n        diff := f64(x) - m\n        sum_sq_diff += diff * diff\n    }\n    return sum_sq_diff / f64(data.len - 1)\n}")

             # py_statistics_stdev
             self.emitter.add_helper_function("fn py_statistics_stdev[T](data []T) f64 {\n    return math.sqrt(py_statistics_variance(data))\n}")

        decimal_used = "decimal" in self.imported_modules.values()
        if not decimal_used:
             decimal_used = "decimal" in used_modules_from_symbols

        if decimal_used:
             # V's math.big provides Rational and Integer, but no arbitrary precision decimal out of the box.
             # Python's decimal operates on base 10 arbitrary precision. For a standard V translation
             # without complex external dependencies, we map Decimal to f64 and approximate the behavior,
             # similar to how standard transpilers fallback to standard types when precision libraries are missing.
             self.emitter.add_helper_struct("type Decimal = f64")
             self.emitter.add_helper_function("fn py_decimal(val Any) Decimal {\n    $if val is $float {\n        return f64(val)\n    } $else $if val is $int {\n        return f64(val)\n    } $else $if val is string {\n        return val.f64()\n    }\n    return 0.0\n}")

             self.emitter.add_helper_struct("struct PyDecimalContext {\nmut:\n    prec int = 28\n}")
             self.emitter.add_helper_function("""
// To approximate a global context without requiring `-enable-globals`,
// we will provide a factory for the context that returns a heap-allocated
// struct. However, this means modifying it does not act globally.
// This is a known limitation of transpiling mutable globals to standard V.
fn py_decimal_getcontext() &PyDecimalContext {
    mut ctx := &PyDecimalContext{prec: 28}
    return ctx
}

fn py_decimal_localcontext() PyDecimalContext {
    return PyDecimalContext{prec: 28}
}

fn (mut ctx PyDecimalContext) close() {
    // Context manager cleanup
}
""")

        pickle_used = "pickle" in self.imported_modules.values()
        if not pickle_used:
             pickle_used = "pickle" in used_modules_from_symbols

        if pickle_used:
             llm_comment = "//##LLM@@ Pickle operations are partially mapped to JSON serialization. This may not handle complex objects or exact pickle semantics. Please review and manually implement correct binary serialization if required."
             # py_pickle_dumps
             self.emitter.add_helper_import("json")
             self.emitter.add_helper_import("os")
             self.emitter.add_helper_function(f"{llm_comment}\nfn py_pickle_dumps[T](obj T) string {{\n    // Warning: Mapped to JSON serialization as partial replacement for pickle\n    return json.encode(obj)\n}}")
             # py_pickle_loads
             self.emitter.add_helper_function(f"{llm_comment}\nfn py_pickle_loads[T](s string) T {{\n    // Warning: Mapped to JSON deserialization as partial replacement for pickle\n    return json.decode(T, s) or {{ panic(err) }}\n}}")
             # py_pickle_dump (to file)
             self.emitter.add_helper_function(f"{llm_comment}\nfn py_pickle_dump[T](obj T, f os.File) {{\n    // Warning: Mapped to JSON serialization\n    s := json.encode(obj)\n    f.write_string(s) or {{ panic(err) }}\n}}")
             # py_pickle_load (from file) - hard because we need to read everything?
             # Or assume file content is valid json.
             self.emitter.add_helper_function(f"{llm_comment}\nfn py_pickle_load[T](f os.File) T {{\n    // Warning: Mapped to JSON deserialization\n    // This assumes the file contains one JSON object\n    // We need to read whole file? or stream?\n    // V json.decode takes string.\n    // We can't easily read from file inside generic func without reading all.\n    // Assuming small file for now, but we don't have read_all on File struct easily exposed in standard way? \n    // actually os.read_file(path) exists. But here we have File object.\n    // Let's panic for now or return zero.\n    panic('pickle.load not fully implemented')\n    return T{{}}\n}}")

        # Helper for dynamic format specifiers
        if "py_format" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_format(val Any, spec string) string {
    // Basic implementation of Python-style formatting
    // Supports: [fill][align][sign][#][0][width][grouping][.precision][type]
    if spec == '' {
        if val is string { return val }
        if val is int { return val.str() }
        if val is i64 { return val.str() }
        if val is f64 { return val.str() }
        if val is bool { return val.str() }
        return '${val}'
    }

    mut fill := ` `
    mut align := `>` // Default for numbers is >, for others is <. Python is complex.

    mut s := spec
    // Alignment
    if s.len >= 2 && (s[1] == `<` || s[1] == `>` || s[1] == `^` || s[1] == `=`) {
        fill = s[0]
        align = s[1]
        s = s[2..]
    } else if s.len >= 1 && (s[0] == `<` || s[0] == `>` || s[0] == `^` || s[0] == `=`) {
        align = s[0]
        s = s[1..]
    }

    // Width
    mut width := 0
    mut j := 0
    for j < s.len && s[j].is_digit() {
        j++
    }
    if j > 0 {
        width = s[..j].int()
        s = s[j..]
    }

    // Precision
    mut precision := -1
    if s.starts_with('.') {
        s = s[1..]
        mut k := 0
        for k < s.len && s[k].is_digit() {
            k++
        }
        if k > 0 {
            precision = s[..k].int()
            s = s[k..]
        }
    }

    // Type
    typ := if s.len > 0 { s[s.len-1] } else { `s` }

    // Simplified formatting
    mut formatted := ''
    if val is f64 {
        prec := if precision >= 0 { precision } else { 6 }
        formatted = '${val:.${prec}f}'
    } else if val is int {
        formatted = '${val}'
    } else if val is i64 {
        formatted = '${val}'
    } else if val is string {
        formatted = val
    } else {
        formatted = '${val}'
    }

    if width > formatted.len {
        pad_len := width - formatted.len
        if align == `<` {
            formatted = formatted + fill.ascii_str().repeat(pad_len)
        } else if align == `>` {
            formatted = fill.ascii_str().repeat(pad_len) + formatted
        } else if align == `^` {
            left := pad_len / 2
            right := pad_len - left
            formatted = fill.ascii_str().repeat(left) + formatted + fill.ascii_str().repeat(right)
        }
    }

    return formatted
}""")

        if "py_string_format_map" in self.used_builtins:
            self.emitter.add_helper_import("strings")
            self.emitter.add_helper_function("""fn py_string_format_map(fmt string, mapping map[string]Any) string {
    mut res := strings.new_builder(fmt.len + 16)
    mut i := 0
    for i < fmt.len {
        if fmt[i] == `{` { // '{'
            if i + 1 < fmt.len && fmt[i+1] == `{` {
                res.write_string('{')
                i += 2
                continue
            }
            mut j := i + 1
            for j < fmt.len && fmt[j] != `}` && fmt[j] != `:` { // '}', ':'
                j++
            }
            if j < fmt.len {
                key := fmt[i+1..j]
                mut spec := ''
                if fmt[j] == `:` { // ':'
                    mut k := j + 1
                    for k < fmt.len && fmt[k] != `}` { // '}'
                        k++
                    }
                    if k < fmt.len {
                        spec = fmt[j+1..k]
                        j = k
                    }
                }

                val := mapping[key] or { panic('KeyError: ' + key) }
                res.write_string(py_format(val, spec))
                i = j + 1
                continue
            }
        } else if fmt[i] == `}` { // '}'
             if i + 1 < fmt.len && fmt[i+1] == `}` {
                res.write_string('}')
                i += 2
                continue
            }
        }
        res.write_u8(fmt[i])
        i++
    }
    return res.str()
}""")

        if "py_repr" in self.used_builtins:
             self.emitter.add_helper_function("fn py_repr(val Any) string {\n    if val is string {\n        return \"'${val}'\"\n    }\n    return '${val}'\n}")

        if "py_ascii" in self.used_builtins:
             self.emitter.add_helper_function("fn py_ascii(val Any) string {\n    // Simplified ascii(): replace non-ascii with \\u escape\n    s := '${val}'\n    mut res := ''\n    for c in s {\n        if c < 128 {\n            res += c.ascii_str()\n        } else {\n            res += '\\\\u${int(c):04x}'\n        }\n    }\n    return res\n}")

        # PyGenerator support
        # We need a generic struct to wrap channels for send/throw/close.
        # We use a wrapper struct for input to support throw (signaling exceptions).
        self.emitter.add_helper_struct("""struct PyGeneratorInput {
    val Any
    is_exc bool
    exc_msg string
}""")

        self.emitter.add_helper_struct("""struct PyGenerator[T] {
mut:
    out chan T
    in_ chan PyGeneratorInput
    open bool = true
}""")
        self.emitter.add_helper_function("""fn (mut g PyGenerator[T]) next() ?T {
    if !g.open { return none }
    g.in_ <- PyGeneratorInput{val: 0} // Send dummy value
    res := <-g.out
    if res == none { g.open = false }
    return res
}""")
        self.emitter.add_helper_function("""fn (mut g PyGenerator[T]) send(val Any) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{val: val}
    res := <-g.out
    if res == none { g.open = false }
    return res
}""")
        self.emitter.add_helper_function("""fn (mut g PyGenerator[T]) throw(msg string) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{is_exc: true, exc_msg: msg}
    res := <-g.out
    if res == none { g.open = false }
    return res
}""")
        self.emitter.add_helper_function("""fn (mut g PyGenerator[T]) close() {
    g.open = false
    g.in_.close()
    // g.out will be closed by the generator function loop when it detects in_ closed or panic
}""")
        # Helper for yield expression: yield val
        # py_yield(ch_out, ch_in, val)
        # Returns the value sent back via send(), or none if next() was called.
        # Panics if throw() was called.
        self.emitter.add_helper_function("""fn py_yield[T](ch_out chan T, ch_in chan PyGeneratorInput, val T) Any {
    ch_out <- val
    inp := <-ch_in
    if inp.is_exc {
        panic(inp.exc_msg)
    }
    return inp.val
}""")

        # Helper for bytes formatting
        self.emitter.add_helper_function("//##LLM@@ String formatting for bytes is stubbed and might be incorrect. Please implement proper bytes formatting or use V string interpolation.\nfn py_bytes_format(fmt []u8, args Any) []u8 {\n    // Simplistic implementation for b'%s' % b'val'\n    // Converts bytes to string, formats, and converts back.\n    // This is not efficient or correct for non-ASCII bytes but works for simple cases.\n    fmt_str := fmt.bytestr()\n    // TODO: handle args properly. V's string interpolation/formatting expects distinct args.\n    // If args is []u8, treat as string.\n    arg_str := if args is []u8 { args.bytestr() } else { '${args}' }\n    \n    // Manual substitution of %s\n    // V does not have sprintf for runtime strings easily available in core without C interop.\n    // Simple replace for %s\n    res := fmt_str.replace('%s', arg_str)\n    return res.bytes()\n}")
        # String formatting helper
        if self.used_string_format:
            self.emitter.add_helper_import("strings")
            self.emitter.add_helper_function("""fn py_string_format(fmt string, args ...Any) string {
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
                        if arg is int {
                            s_val = '${arg}'
                        } else if arg is i64 {
                            s_val = '${arg}'
                        } else if arg is f64 {
                            s_val = '${int(arg)}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int}'
                        }
                        if flag_zero && width > s_val.len && !flag_minus {
                             s_val = '0'.repeat(width - s_val.len) + s_val
                        }
                    } else if spec == `f` || spec == `F` {
                        // Float formatting
                        prec := if precision >= 0 { precision } else { 6 }
                        if arg is f64 {
                            s_val = '${arg:.${prec}f}'
                        } else if arg is int {
                            s_val = '${f64(arg):.${prec}f}'
                        } else if arg is i64 {
                            s_val = '${f64(arg):.${prec}f}'
                        } else {
                            val_f := '${arg}'.f64()
                            s_val = '${val_f:.${prec}f}'
                        }
                    } else if spec == `e` || spec == `E` {
                        prec := if precision >= 0 { precision } else { 6 }
                        if arg is f64 {
                            s_val = '${arg:.${prec}e}'
                        } else if arg is int {
                            s_val = '${f64(arg):.${prec}e}'
                        } else if arg is i64 {
                            s_val = '${f64(arg):.${prec}e}'
                        } else {
                            val_f := '${arg}'.f64()
                            s_val = '${val_f:.${prec}e}'
                        }
                    } else if spec == `g` || spec == `G` {
                        // V doesn't strictly support %g in interpolation same as C, but close enough
                        if arg is f64 {
                            s_val = '${arg}'
                        } else if arg is int {
                            s_val = '${f64(arg)}'
                        } else if arg is i64 {
                            s_val = '${f64(arg)}'
                        } else {
                            val_f := '${arg}'.f64()
                            s_val = '${val_f}'
                        }
                    } else if spec == `x` {
                        if arg is int {
                            s_val = '${arg:x}'
                        } else if arg is i64 {
                            s_val = '${arg:x}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int:x}'
                        }
                    } else if spec == `X` {
                        if arg is int {
                            s_val = '${arg:X}'
                        } else if arg is i64 {
                            s_val = '${arg:X}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int:X}'
                        }
                    } else if spec == `o` {
                        if arg is int {
                            s_val = '${arg:o}'
                        } else if arg is i64 {
                            s_val = '${arg:o}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int:o}'
                        }
                    } else if spec == `r` {
                        s_val = '${arg}'
                    } else if spec == `c` {
                        if arg is int {
                            s_val = u8(arg).ascii_str()
                        } else if arg is i64 {
                            s_val = u8(arg).ascii_str()
                        } else if arg is f64 {
                            s_val = u8(int(arg)).ascii_str()
                        } else {
                            val_int := '${arg}'.int()
                            s_val = u8(val_int).ascii_str()
                        }
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

        if "py_list_pop_at" in self.used_builtins or "py_list_remove" in self.used_builtins:
            self.emitter.add_helper_function("")
        if "py_list_pop_at" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_list_pop_at[T](mut a []T, index int) T {
    mut i := index
    if i < 0 { i += a.len }
    res := a[i]
    a.delete(i)
    return res
}""")

        if "py_list_remove" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_list_remove[T](mut a []T, val T) {
    idx := a.index(val)
    if idx >= 0 {
        a.delete(idx)
    }
}""")

        if self.used_delete_many:
            self.emitter.add_helper_function("""fn (mut a []T) delete_many[T](start int, count int) {
    if count <= 0 { return }
    a.delete(start, start + count)
}""")

        if self.used_insert_many:
            self.emitter.add_helper_function("""fn (mut a []T) insert_many[T](index int, val []T) {
    a.insert(index, val)
}""")

        if self.used_list_concat:
            self.emitter.add_helper_function("""fn py_list_concat[T](lists ...[]T) []T {
    mut res := []T{}
    for l in lists {
        res << l
    }
    return res
}""")

        if self.used_dict_merge:
            self.emitter.add_helper_function("""fn py_dict_merge[K, V](dicts ...map[K]V) map[K]V {
    mut res := map[K]V{}
    for d in dicts {
        for k, v in d {
            res[k] = v
        }
    }
    return res
}""")

        if "py_dict_pop" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_pop[K, V](mut d map[K]V, key K, default V) V {
    if key in d {
        val := d[key]
        d.delete(key)
        return val
    }
    return default
}""")

        if "py_dict_update" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_update[K, V](mut d map[K]V, other ...map[K]V) map[K]V {
    for o in other {
        for k, v in o {
            d[k] = v
        }
    }
    return d
}""")

        if "py_dict_setdefault" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_setdefault[K, V](mut d map[K]V, key K, default V) V {
    if key in d {
        return d[key]
    }
    d[key] = default
    return default
}""")

        if "py_dict_fromkeys" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_fromkeys[M, K, V](keys []K, val V) M {
    mut res := M{ }
    for k in keys {
        res[k] = val
    }
    return res
}""")

        if "py_dict_from_pairs" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_from_pairs[M, K, V](pairs [][]Any) M {
    mut res := M{ }
    for p in pairs {
        if p.len >= 2 {
            mut key := K{}
            $if K is string {
                 key = (p[0] as string)
            } $else $if K is int {
                 key = (p[0] as int)
            } $else {
                 key = (p[0] as K)
            }
            mut value := V{}
             $if V is Any {
                 value = p[1]
            } $else {
                 value = (p[1] as V)
            }
            res[key] = value
        }
    }
    return res
}""")

        if "py_set_union" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_set_union[K](a map[K]bool, b map[K]bool) map[K]bool {
    mut res := a.clone()
    for k, v in b {
        res[k] = v
    }
    return res
}""")

        if "py_set_intersection" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_set_intersection[K](a map[K]bool, b map[K]bool) map[K]bool {
    mut res := map[K]bool{}
    for k, _ in a {
        if k in b {
            res[k] = true
        }
    }
    return res
}""")

        if "py_set_difference" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_set_difference[K](a map[K]bool, b map[K]bool) map[K]bool {
    mut res := map[K]bool{}
    for k, _ in a {
        if k !in b {
            res[k] = true
        }
    }
    return res
}""")

        if "py_set_xor" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_set_xor[K](a map[K]bool, b map[K]bool) map[K]bool {
    mut res := map[K]bool{}
    for k, _ in a {
        if k !in b {
            res[k] = true
        }
    }
    for k, _ in b {
        if k !in a {
            res[k] = true
        }
    }
    return res
}""")

        if "py_dict_residual" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_residual[K, V](m map[K]V, exclude []K) map[K]Any {
    mut res := map[K]Any{}
    for k, v in m {
        if k !in exclude {
            res[k] = Any(v)
        }
    }
    return res
}""")

        if "py_subscript" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_subscript(obj Any, idx Any) Any {
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
            self.emitter.add_helper_function("""fn py_slice(obj Any, lower ?Any, upper ?Any, step ?Any) Any {
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
        mut s := 1
        if step_val := step {
            if step_val is int { s = step_val }
        }

        if l < 0 { l += obj.len }
        if u < 0 { u += obj.len }
        if l < 0 { l = 0 }
        if u > obj.len { u = obj.len }

        if s == 1 {
            if l >= u { return '' }
            return obj[l..u]
        } else if s == -1 {
            if l == 0 && u == obj.len {
                return py_str_reverse(obj)
            }
            // more complex case not fully implemented for dynamic Any
            return py_str_reverse(obj) // fallback
        }

        return py_str_slice(obj, lower, upper, step)
    } else if obj is []u8 {
        // ... similar for bytes if needed
        return obj // stub
    }
    panic('py_slice: unsupported type or bounds')
    return false
}""")

        if "py_str_reverse" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_str_reverse(s string) string {
    return s.runes().reverse().string()
}""")

        if "py_list_reverse" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_list_reverse[T](l []T) []T {
    mut res := l.clone()
    res.reverse()
    return res
}""")

        if "py_str_slice" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_str_slice(s string, lower ?Any, upper ?Any, step ?Any) string {
    mut l := 0
    if lower_val := lower { if lower_val is int { l = lower_val } }
    mut u := s.len
    if upper_val := upper { if upper_val is int { u = upper_val } }
    mut st := 1
    if step_val := step { if step_val is int { st = step_val } }

    if l < 0 { l += s.len }
    if u < 0 { u += s.len }
    if l < 0 { l = 0 }
    if u > s.len { u = s.len }

    if st == 1 { return s[l..u] }

    runes := s.runes()
    mut res_runes := []rune{}
    if st > 0 {
        for i := l; i < u; i += st {
            if i >= 0 && i < runes.len { res_runes << runes[i] }
        }
    } else if st < 0 {
        // In Python, if step < 0, it goes from lower down to upper (exclusive)
        // Defaults for l and u are also different.
        // This is a simplified version.
        for i := l; i > u; i += st {
             if i >= 0 && i < runes.len { res_runes << runes[i] }
        }
    }
    return res_runes.string()
}""")

        if "py_list_slice" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_list_slice[T](l []T, lower ?Any, upper ?Any, step ?Any) []T {
    mut lo := 0
    if lower_val := lower { if lower_val is int { lo = lower_val } }
    mut up := l.len
    if upper_val := upper { if upper_val is int { up = upper_val } }
    mut st := 1
    if step_val := step { if step_val is int { st = step_val } }

    if lo < 0 { lo += l.len }
    if up < 0 { up += l.len }
    if lo < 0 { lo = 0 }
    if up > l.len { up = l.len }

    if st == 1 { return l[lo..up].clone() }

    mut res := []T{}
    if st > 0 {
        for i := lo; i < up; i += st {
            if i >= 0 && i < l.len { res << l[i] }
        }
    } else if st < 0 {
        for i := lo; i > up; i += st {
            if i >= 0 && i < l.len { res << l[i] }
        }
    }
    return res
}""")
        if "py_any" in self.used_builtins:
            self.used_builtins.add("py_bool")
            self.emitter.add_helper_function("""pub fn py_any[T](a []T) bool {
    for it in a {
        $if T is bool {
            if it { return true }
        } $else $if T is int {
            if it != 0 { return true }
        } $else $if T is i64 {
            if it != 0 { return true }
        } $else $if T is f64 {
            if it != 0.0 { return true }
        } $else $if T is string {
            if it.len > 0 { return true }
        } $else $if T is Any {
            if py_bool(it) { return true }
        } $else {
            if it != none { return true }
        }
    }
    return false
}""")

        if "py_all" in self.used_builtins:
            self.used_builtins.add("py_bool")
            self.emitter.add_helper_function("""pub fn py_all[T](a []T) bool {
    for it in a {
        $if T is bool {
            if !it { return false }
        } $else $if T is int {
            if it == 0 { return false }
        } $else $if T is i64 {
            if it == 0 { return false }
        } $else $if T is f64 {
            if it == 0.0 { return false }
        } $else $if T is string {
            if it.len == 0 { return false }
        } $else $if T is Any {
            if !py_bool(it) { return false }
        } $else {
            if it == none { return false }
        }
    }
    return true
}""")

        if "py_bool" in self.used_builtins:
            self.emitter.add_helper_function("""pub fn py_bool(val Any) bool {
    if val is bool { return val }
    if val is int { return val != 0 }
    if val is i64 { return val != 0 }
    if val is f64 { return val != 0.0 }
    if val is string { return val.len > 0 }
    if val is []Any { return val.len > 0 }
    if val is map[string]Any { return val.len > 0 }
    if val is NoneType { return false }
    return true
}""")

        if 'py_iter' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_iter[T](obj T) T { return obj }")

        if 'py_list_from_iter' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_list_from_iter[U](mut it U) []Any { mut res := []Any{}; for { val := it.next() or { break }; res << val }; return res }")

        if 'py_set_from_iter' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_set_from_iter[U](mut it U) map[string]bool { mut res := map[string]bool{}; for { val := it.next() or { break }; res[val.str()] = true }; return res }")

        if 'py_sum' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_sum[T](a []T) T { mut s := T{}; for x in a { s += x }; return s }")

        if 'py_sorted' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_sorted[T](a []T, reverse bool) []T { mut res := a.clone(); res.sort(a < b); if reverse { res.reverse() }; return res }")

        if 'py_reversed' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_reversed[T](a []T) []T { mut res := a.clone(); res.reverse(); return res }")

        if 'py_min' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_min[T](a []T) T { if a.len == 0 { panic('min() arg is an empty sequence') }; mut m := a[0]; for x in a { if x < m { m = x } }; return m }")

        if 'py_max' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_max[T](a []T) T { if a.len == 0 { panic('max() arg is an empty sequence') }; mut m := a[0]; for x in a { if x > m { m = x } }; return m }")

        if 'py_zip' in self.used_builtins:
             self.emitter.add_helper_struct("pub struct PyZipItem[T, U] {\npub:\n    a T\n    b U\n}")
             self.emitter.add_helper_function("pub fn py_zip[T, U](a []T, b []U) []PyZipItem[T, U] { mut res := []PyZipItem[T, U]{}; limit := if a.len < b.len { a.len } else { b.len }; for i in 0..limit { res << PyZipItem[T, U]{a: a[i], b: b[i]} }; return res }")

        if 'py_enumerate' in self.used_builtins:
             self.emitter.add_helper_struct("pub struct PyEnumerateItem[T] {\npub:\n    index int\n    value T\n}")
             self.emitter.add_helper_function("pub fn py_enumerate[T](a []T) []PyEnumerateItem[T] { mut res := []PyEnumerateItem[T]{}; for i, x in a { res << PyEnumerateItem[T]{index: i, value: x} }; return res }")

        if 'py_range' in self.used_builtins:
             self.emitter.add_helper_function("pub fn py_range(args ...int) []int { mut res := []int{}; if args.len == 1 { for i in 0..args[0] { res << i } } else if args.len == 2 { for i in args[0]..args[1] { res << i } } else if args.len == 3 { start := args[0]; stop := args[1]; step := args[2]; if step > 0 { for i := start; i < stop; i += step { res << i } } else if step < 0 { for i := start; i > stop; i += step { res << i } } }; return res }")

        if 'py_random_sample' in self.used_builtins:
             self.emitter.add_helper_import('rand')
             self.emitter.add_helper_function("pub fn py_random_sample[T](a []T, k int) []T { if k > a.len { panic('sample larger than population') }; mut res := []T{}; mut indices := []int{len: a.len}; for i in 0..a.len { indices[i] = i }; rand.shuffle(mut indices) or { panic(err) }; for i in 0..k { res << a[indices[i]] }; return res }")

        if 'py_divmod' in self.used_builtins:
             self.emitter.add_helper_import('math')
             self.emitter.add_helper_function("""pub fn py_divmod[T](a T, b T) []T {
    $if T is f64 {
        q := math.floor(a / b)
        r := a - q * b
        return [q, r]
    } $else {
        return [a / b, a % b]
    }
}""")

        if 'py_os_path_split' in self.used_builtins:
             self.emitter.add_helper_import('os')
             self.emitter.add_helper_function("pub fn py_os_path_split(path string) []string { return [os.dir(path), os.base(path)] }")

        if 'py_os_path_splitext' in self.used_builtins:
             self.emitter.add_helper_import('os')
             self.emitter.add_helper_function("pub fn py_os_path_splitext(path string) []string { ext := os.file_ext(path); return [path[..path.len - ext.len], ext] }")

        return self.emitter.emit()
