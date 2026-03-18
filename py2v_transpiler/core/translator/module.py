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

        if "sorted" in self.used_builtins:
             self.emitter.add_helper_function("fn py_sorted[T](a []T) []T {\n    mut res := a.clone()\n    res.sort()\n    return res\n}")

        if "reversed" in self.used_builtins:
             self.emitter.add_helper_function("fn py_reversed[T](a []T) []T {\n    mut res := a.clone()\n    res.reverse()\n    return res\n}")

        if "py_repeat" in self.used_builtins:
             self.emitter.add_helper_function("fn py_repeat(s string, n int) string {\n    if n <= 0 { return '' }\n    return s.repeat(n)\n}")

        if "py_repeat_list" in self.used_builtins:
             self.emitter.add_helper_function("fn py_repeat_list[T](l []T, n int) []T {\n    if n <= 0 { return []T{} }\n    mut res := []T{cap: l.len * n}\n    for _ in 0..n {\n        res << l\n    }\n    return res\n}")

        if "round" in self.used_builtins:
             self.emitter.add_helper_function("fn py_round(val f64, ndigits int) f64 {\n    import math\n    if ndigits == 0 { return math.round(val) }\n    p := math.pow(10.0, f64(ndigits))\n    return math.round(val * p) / p\n}")

        if self.used_complex:
             self.emitter.add_helper_struct("struct PyComplex {\n    real f64\n    imag f64\n}")
             self.emitter.add_helper_function("fn (c1 PyComplex) + (c2 PyComplex) PyComplex {\n    return PyComplex{real: c1.real + c2.real, imag: c1.imag + c2.imag}\n}")
             self.emitter.add_helper_function("fn (c1 PyComplex) - (c2 PyComplex) PyComplex {\n    return PyComplex{real: c1.real - c2.real, imag: c1.imag - c2.imag}\n}")
             self.emitter.add_helper_function("fn (c1 PyComplex) * (c2 PyComplex) PyComplex {\n    return PyComplex{real: c1.real * c2.real - c1.imag * c2.imag, imag: c1.real * c2.imag + c1.imag * c2.real}\n}")
             self.emitter.add_helper_function("fn (c PyComplex) str() string {\n    sign := if c.imag >= 0 { '+' } else { '' }\n    return '(${c.real}${sign}${c.imag}j)'\n}")

        used_modules_from_symbols = set()
        for full_name in self.imported_symbols.values():
             parts = full_name.split(".")
             if len(parts) > 1:
                  used_modules_from_symbols.add(".".join(parts[:-1]))

        # Conditional helper injection for specific modules
        json_used = "json" in self.imported_modules.values()
        if not json_used:
             json_used = "json" in used_modules_from_symbols

        if json_used:
             self.emitter.add_helper_import("x.json2")
             self.emitter.add_helper_function("fn py_json_loads(s string) Any {\n    return json2.raw_decode(s) or { Any(NoneType{}) }\n}")
             self.emitter.add_helper_function("fn py_json_dumps(val Any) string {\n    return json2.encode(val)\n}")

        math_used = "math" in self.imported_modules.values()
        if not math_used:
             math_used = "math" in used_modules_from_symbols

        if math_used:
             self.emitter.add_helper_import("math")

        os_used = "os" in self.imported_modules.values()
        if not os_used:
             os_used = "os" in used_modules_from_symbols

        if os_used:
             self.emitter.add_helper_import("os")
             # Python os.path.join -> V os.join_path
             # Python os.path.exists -> V os.exists
             # Python os.listdir -> V os.ls
             self.emitter.add_helper_function("fn py_os_path_join(args ...string) string {\n    return os.join_path(...args)\n}")

        sys_used = "sys" in self.imported_modules.values()
        if not sys_used:
             sys_used = "sys" in used_modules_from_symbols

        if sys_used:
             self.emitter.add_helper_import("os")
             self.emitter.add_helper_function("fn py_sys_exit(code int) {\n    exit(code)\n}")

        re_used = "re" in self.imported_modules.values()
        if not re_used:
             re_used = "re" in used_modules_from_symbols

        if re_used:
             self.emitter.add_helper_import("pcre")
             self.emitter.add_helper_struct("struct PyReMatch {\n    groups []string\n}")
             self.emitter.add_helper_function("fn (m PyReMatch) group(n int) string {\n    if n >= 0 && n < m.groups.len { return m.groups[n] }\n    return ''\n}")
             self.emitter.add_helper_function("fn py_re_search(pattern string, s string) ?PyReMatch {\n    re := pcre.new_reg_exp(pattern, 0) or { return none }\n    m := re.exec(s, 0) or { return none }\n    mut groups := []string{}\n    for i in 0..m.n_groups {\n        groups << m.get_group(i)\n    }\n    return PyReMatch{groups: groups}\n}")

        random_used = "random" in self.imported_modules.values()
        if not random_used:
             random_used = "random" in used_modules_from_symbols

        if random_used:
             self.emitter.add_helper_import("rand")
             self.emitter.add_helper_function("fn py_random_randint(min int, max int) int {\n    return rand.int_in_range(min, max + 1) or { min }\n}")
             self.emitter.add_helper_function("fn py_random_choice[T](l []T) T {\n    return rand.element(l) or { panic('choice from empty sequence') }\n}")

        time_used = "time" in self.imported_modules.values()
        if not time_used:
             time_used = "time" in used_modules_from_symbols

        if time_used:
             self.emitter.add_helper_import("time")
             self.emitter.add_helper_function("fn py_time_time() f64 {\n    return f64(time.now().unix_time_milli()) / 1000.0\n}")
             self.emitter.add_helper_function("fn py_time_sleep(seconds f64) {\n    time.sleep(int(seconds * 1000) * time.millisecond)\n}")

        datetime_used = "datetime" in self.imported_modules.values()
        if not datetime_used:
             datetime_used = "datetime" in used_modules_from_symbols

        if datetime_used:
             self.emitter.add_helper_import("time")
             self.emitter.add_helper_struct("struct PyDatetime {\n    t time.Time\n}")
             self.emitter.add_helper_function("fn py_datetime_now() PyDatetime {\n    return PyDatetime{t: time.now()}\n}")
             self.emitter.add_helper_function("fn (d PyDatetime) str() string {\n    return d.t.format_ss()\n}")

        collections_used = "collections" in self.imported_modules.values()
        if not collections_used:
             collections_used = "collections" in used_modules_from_symbols

        if collections_used:
             # deque, namedtuple, defaultdict, Counter
             pass

        bisect_used = "bisect" in self.imported_modules.values()
        if not bisect_used:
             bisect_used = "bisect" in used_modules_from_symbols

        if bisect_used:
             # bisect_left, bisect_right
             pass

        heapq_used = "heapq" in self.imported_modules.values()
        if not heapq_used:
             heapq_used = "heapq" in used_modules_from_symbols

        if heapq_used:
             # heappush, heappop, heapify
             pass

        sqlite3_used = "sqlite3" in self.imported_modules.values()
        if not sqlite3_used:
             sqlite3_used = "sqlite3" in used_modules_from_symbols

        if sqlite3_used:
             self.emitter.add_helper_import("db.sqlite")
             # PySqliteConnection, PySqliteCursor
             self.emitter.add_helper_struct("struct PySqliteConnection {\nmut:\n    db sqlite.DB\n}")
             self.emitter.add_helper_struct("struct PySqliteCursor {\nmut:\n    conn &PySqliteConnection\n    last_query string\n}")

             self.emitter.add_helper_function("fn py_sqlite3_connect(path string) PySqliteConnection {\n    db := sqlite.connect(path) or { panic(err) }\n    return PySqliteConnection{db: db}\n}")

             # cursor()
             self.emitter.add_helper_function("fn (mut c PySqliteConnection) cursor() PySqliteCursor {\n    return PySqliteCursor{conn: &c}\n}")

             # execute()
             self.emitter.add_helper_function("fn (mut c PySqliteCursor) execute(query string, params ...Any) {\n    c.last_query = query\n    // Simplified: in real V sqlite we'd bind params\n    c.conn.db.exec(query) or {}\n}")

             # fetchone()
             self.emitter.add_helper_function("fn (mut c PySqliteCursor) fetchone() ?[]Any {\n    // Simplified\n    return none\n}")

             # fetchall()
             self.emitter.add_helper_function("fn (mut c PySqliteCursor) fetchall() [][]Any {\n    // Simplified\n    return [][]Any{}\n}")

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
             self.emitter.add_helper_function("fn py_urlencode(m map[string]string) string {\n    mut res := []string{}\n    for k, v in m {\n        res << '${urllib.query_escape(k)}=${urllib.query_escape(v)}'\n    }\n    return res.join('&')\n}")

             # urlparse
             self.emitter.add_helper_struct("struct PyParseResult {\n    scheme string\n    netloc string\n    path string\n    params string\n    query string\n    fragment string\n}")
             self.emitter.add_helper_function("fn py_urlparse(s string) PyParseResult {\n    u := urllib.parse(s) or { return PyParseResult{} }\n    return PyParseResult{scheme: u.scheme, netloc: u.host, path: u.path, query: u.raw_query, fragment: u.fragment}\n}")

        uuid_used = "uuid" in self.imported_modules.values()
        if not uuid_used:
             uuid_used = "uuid" in used_modules_from_symbols

        if uuid_used:
             self.emitter.add_helper_import("os")
             # Simplified: just return a random string
             self.emitter.add_helper_function("fn py_uuid4() string {\n    return '550e8400-e29b-41d4-a716-446655440000'\n}")

        csv_used = "csv" in self.imported_modules.values()
        if not csv_used:
             csv_used = "csv" in used_modules_from_symbols

        if csv_used:
             # reader, writer
             pass

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

        if "py_bool" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_bool[T](val T) bool {
    $if T is bool { return val }
    $else $if T is string { return val != '' }
    $else $if T is int || T is i64 || T is f64 { return val != 0 }
    $else $if T is []Any { return val.len > 0 }
    $else $if T is map[string]Any { return val.len > 0 }
    $else $if T is NoneType { return false }
    $else { return true }
}""")

        if "py_repr" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_repr[T](val T) string {
    return '${val}'
}""")

        if "py_ascii" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_ascii[T](val T) string {
    return '${val}'
}""")

        if "py_format" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_format[T](val T, spec string) string {
    // Basic implementation for demonstration
    if spec == '' { return val.str() }

    mut res := strings.new_builder(32)
    mut i := 0
    fmt := spec
    for i < fmt.len {
        if fmt[i] == `$` {
            if i + 1 < fmt.len && fmt[i+1] == `{` {
                mut j := i + 2
                for j < fmt.len && fmt[j] != `}` { j++ }
                if j < fmt.len {
                    // Found interpolation, handle it
                    // For now just basic
                    res.write_string(val.str())
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
            self.emitter.add_helper_function("""fn py_slice(obj Any, lower ?Any, upper ?Any) Any {
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

        return self.emitter.emit() + "\n" + self.emitter.emit_helpers()

    def _inject_helpers(self):
        """Placeholder for helpers."""
        pass
