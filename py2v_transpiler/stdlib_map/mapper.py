from typing import Dict, List, Callable, Union, Optional

class StdLibMapper:
    def __init__(self):
        # Maps Python module -> { Python function -> V function or transformation }
        self.mappings: Dict[str, Dict[str, Union[str, Callable[[List[str]], str]]]] = {
            "math": {
                "sqrt": "math.sqrt",
                "sin": "math.sin",
                "cos": "math.cos",
                "tan": "math.tan",
                "asin": "math.asin",
                "acos": "math.acos",
                "atan": "math.atan",
                "atan2": "math.atan2",
                "sinh": "math.sinh",
                "cosh": "math.cosh",
                "tanh": "math.tanh",
                "exp": "math.exp",
                "log": "math.log",
                "log10": "math.log10",
                "pow": "math.pow",
                "ceil": "math.ceil",
                "floor": "math.floor",
                "fabs": "math.abs",
                "pi": "math.pi",
                "e": "math.e",
                "degrees": "math.degrees",
                "radians": "math.radians",
            },
            "random": {
                "randint": self._random_randint,
                "random": "rand.f64",
                "choice": self._random_choice,
                "seed": "rand.seed",
            },
            "json": {
                "loads": self._json_loads,
                "dumps": "json.encode",
            },
            "time": {
                "time": self._time_time,
                "sleep": self._time_sleep,
            },
            "datetime": {
                "datetime.now": "time.now",
                "date.today": "time.now",
            },
            "sys": {
                "exit": "exit",
                "argv": "os.args",
                "platform": "os.user_os()", # Approximation
            },
            "io": {
                "StringIO": self._io_stringio,
            },
            "six.moves": {
                "StringIO": self._io_stringio,
            },
            "os": {
                "environ": "os.environ()",
                "getcwd": "os.getwd",
                "system": "os.system",
                "getenv": "os.getenv",
                "mkdir": "os.mkdir",
                "makedirs": "os.mkdir_all",
                "remove": "os.rm",
                "rmdir": "os.rmdir",
                "listdir": "os.ls",
                "path.join": "os.join_path",
                "path.exists": "os.exists",
                "path.isfile": "os.is_file",
                "path.isdir": "os.is_dir",
                "path.abspath": "os.abs_path",
                "path.basename": "os.base",
                "path.dirname": "os.dir",
            },
            "re": {
                "match": "regex.regex_opt", # V regex is different, simplified mapping
                "search": "regex.regex_opt",
                "compile": "regex.regex_opt",
            },
            "unittest": {
                # Handled structurally in translator, but map here to avoid errors
            },
            "shutil": {
                "copy": self._shutil_copy,
                "copy2": self._shutil_copy,
                "copyfile": self._shutil_copy,
                "move": self._shutil_move,
                "rmtree": self._shutil_rmtree,
                "copytree": self._shutil_copytree,
                "which": self._shutil_which,
                "chown": "os.chown",
                # "disk_usage": "os.disk_usage", # Not confirmed in V stdlib
            },
            "tempfile": {
                "gettempdir": "os.temp_dir",
                "mkstemp": self._tempfile_mkstemp,
                "mkdtemp": self._tempfile_mkdtemp,
                "NamedTemporaryFile": self._tempfile_named_temporary_file,
                "TemporaryDirectory": self._tempfile_temporary_directory,
            },
            "logging": {
                "info": "log.info",
                "warning": "log.warn",
                "error": "log.error",
                "debug": "log.debug",
                "critical": "log.error",
                "getLogger": self._logging_get_logger,
                "basicConfig": self._logging_basic_config,
            },
            "argparse": {
                "ArgumentParser": "py_argparse_new",
            },
            "uuid": {
                "uuid4": "rand.uuid_v4",
            },
            "collections": {
                "defaultdict": self._collections_defaultdict,
                "Counter": self._collections_Counter,
            },
            "itertools": {
                "chain": "py_chain",
                "repeat": self._itertools_repeat,
                "count": self._itertools_count,
                "cycle": "py_cycle",
            },
            "functools": {
                "reduce": "py_reduce",
            },
            "operator": {
                "add": "py_op_add",
                "sub": "py_op_sub",
                "mul": "py_op_mul",
                "truediv": "py_op_div",
                "floordiv": "py_op_div", # V / is integer div for ints
                "mod": "py_op_mod",
                "pow": "math.pow", # Helper needed or direct usage
                "eq": "py_op_eq",
                "ne": "py_op_ne",
                "lt": "py_op_lt",
                "le": "py_op_le",
                "gt": "py_op_gt",
                "ge": "py_op_ge",
                "not_": "py_op_not",
                "and_": "py_op_and",
                "or_": "py_op_or",
                "xor": "py_op_xor",
            },
            "threading": {
                "Thread": "PyThread",
                "Lock": self._threading_lock,
            },
            "socket": {
                "socket": "py_socket_new",
                "AF_INET": "py_AF_INET", # Constants
                "SOCK_STREAM": "py_SOCK_STREAM",
            },
            "pathlib": {
                "Path": "py_path_new",
            },
            "urllib.request": {
                "urlopen": "py_urlopen",
            },
            "http.client": {
                "HTTPConnection": "py_http_connection",
            },
            "csv": {
                "reader": "py_csv_reader",
                "writer": "py_csv_writer",
            },
            "sqlite3": {
                "connect": "py_sqlite_connect",
            },
            "subprocess": {
                "run": "py_subprocess_run",
                "call": "py_subprocess_call",
            },
            "platform": {
                "system": "os.user_os",
                "machine": "py_platform_machine",
                "python_implementation": self._platform_python_implementation,
            },
            "hashlib": {
                "sha256": "py_hash_sha256",
                "md5": "py_hash_md5",
            },
            "base64": {
                "b64encode": "base64.encode",
                "b64decode": "base64.decode",
                "standard_b64encode": "base64.encode",
                "standard_b64decode": "base64.decode",
                "urlsafe_b64encode": "base64.url_encode",
                "urlsafe_b64decode": "base64.url_decode",
            },
            "urllib.parse": {
                "urlparse": "py_urlparse",
                "quote": "urllib.query_escape",
                "quote_plus": "urllib.query_escape",
                "unquote": "py_urllib_unquote",
                "unquote_plus": "py_urllib_unquote",
                "urlencode": "py_urlencode",
            },
            "zlib": {
                "compress": "py_zlib_compress",
                "decompress": "py_zlib_decompress",
            },
            "gzip": {
                "compress": "py_gzip_compress",
                "decompress": "py_gzip_decompress",
            },
            "copy": {
                "copy": "py_copy",
                "deepcopy": "py_deepcopy",
            },
            "struct": {
                "pack": self._struct_pack,
                "unpack": self._struct_unpack,
                "calcsize": "py_struct_calcsize",
            },
            "array": {
                "array": self._array_array,
            },
            "fractions": {
                "Fraction": self._fractions_Fraction,
            },
            "statistics": {
                "mean": "py_statistics_mean",
                "median": "py_statistics_median",
                "mode": "py_statistics_mode",
                "stdev": "py_statistics_stdev",
                "variance": "py_statistics_variance",
            },
            "decimal": {
                "Decimal": "py_decimal",
                "localcontext": "py_decimal_localcontext",
                "getcontext": "py_decimal_getcontext",
            },
            "pickle": {
                "dumps": "py_pickle_dumps",
                "loads": "py_pickle_loads",
                "dump": "py_pickle_dump",
                "load": "py_pickle_load",
            },
            "contextlib": {
                "closing": self._contextlib_closing,
                "nullcontext": self._contextlib_nullcontext,
                "suppress": self._contextlib_suppress,
                "redirect_stdout": self._contextlib_redirect_stdout,
            },
            "typing": {
                "cast": self._typing_cast,
            }
        }

        # Maps Python module -> List of V imports
        self.v_imports: Dict[str, List[str]] = {
            "math": ["math"],
            "random": ["rand"],
            "json": ["json"],
            "time": ["time"],
            "datetime": ["time"],
            "sys": ["os"],
            "io": ["strings"],
            "six.moves": ["strings"],
            "os": ["os"],
            "re": ["regex"],
            "shutil": ["os"],
            "unittest": [], # No import needed in V if we translate to assert
            "tempfile": ["os"],
            "logging": ["log"],
            "argparse": ["os"],
            "uuid": ["rand"],
            "collections": [],
            "itertools": [],
            "functools": [],
            "operator": [],
            "threading": ["sync"],
            "socket": ["net"],
            "pathlib": ["os"],
            "urllib.request": ["net.http"],
            "http.client": ["net.http"],
            "csv": ["encoding.csv"],
            "sqlite3": ["db.sqlite"],
            "subprocess": ["os"],
            "platform": ["os"],
            "hashlib": ["crypto.sha256", "crypto.md5", "encoding.hex"],
            "base64": ["encoding.base64"],
            "urllib.parse": ["net.urllib"],
            "zlib": ["compress.zlib"],
            "gzip": ["compress.gzip"],
            "copy": [],
            "struct": ["encoding.binary"],
            "array": [],
            "fractions": ["math.fractions"],
            "statistics": ["math"],
            "decimal": [],
            "pickle": ["json"],
            "contextlib": [],
            "typing": [],
        }

    def get_mapping(self, module: str, func: str, args: List[str]) -> Optional[str]:
        """
        Returns the V code for a given module and function call.
        If no mapping is found, returns None.
        """
        if module not in self.mappings:
            return None

        module_map = self.mappings[module]
        if func not in module_map:
            return None

        handler = module_map[func]

        if callable(handler):
            return handler(args)
        elif isinstance(handler, str):
            # If it's a string, it's a direct function name replacement
            # E.g. math.sqrt -> math.sqrt
            # We just construct the call with args
            return f"{handler}({', '.join(args)})"

        return None

    def get_constant_mapping(self, module: str, name: str) -> Optional[str]:
        """
        Returns the V code for a given module constant.
        """
        if module not in self.mappings:
            return None

        module_map = self.mappings[module]
        if name not in module_map:
            return None

        handler = module_map[name]
        if isinstance(handler, str):
             # Ensure it doesn't look like a function call if it's a constant
             # But our map mixes functions and constants (e.g. math.pi)
             # We assume if it's called via this method, it's an attribute access, not a call.
             return handler
        return None

    def get_imports(self, module: str) -> Optional[List[str]]:
        """
        Returns list of V imports for a Python module.
        Returns None if module is unknown/not mapped.
        Returns [] if module is known but needs no imports.
        """
        return self.v_imports.get(module)

    # specialized handlers

    def _io_stringio(self, args: List[str]) -> str:
        if len(args) == 0:
            return "strings.new_builder(1024)"
        return f"py_io_stringio({args[0]})"

    def _random_randint(self, args: List[str]) -> str:
        if len(args) == 2:
            return f"rand.intn({args[1]} - {args[0]} + 1) + {args[0]}"
        return "/* random.randint args error */"

    def _random_choice(self, args: List[str]) -> str:
        if len(args) == 1:
            return f"{args[0]}[rand.intn({args[0]}.len)]"
        return "/* random.choice args error */"

    def _json_loads(self, args: List[str]) -> str:
        if len(args) >= 1:
             # Default to map[string]string for generic JSON object
             return f"json.decode(map[string]string, {args[0]}) or {{}}"
        return "/* json.loads args error */"

    def _time_time(self, args: List[str]) -> str:
        if len(args) == 0:
            return "f64(time.now().unix_time_milli()) / 1000.0"
        return "/* time.time args error */"

    def _time_sleep(self, args: List[str]) -> str:
        if len(args) == 1:
            # Python sleep is seconds, V sleep is duration (ns)
            # We use time.second * duration
            # But args[0] might be float or int.
            # safe cast?
            return f"time.sleep({args[0]} * time.second)"
        return "/* time.sleep args error */"

    def _shutil_copy(self, args: List[str]) -> str:
        if len(args) >= 2:
            return f"os.cp({args[0]}, {args[1]}) or {{ panic(err) }}"
        return "/* shutil.copy args error */"

    def _shutil_move(self, args: List[str]) -> str:
        if len(args) >= 2:
            return f"os.mv({args[0]}, {args[1]}) or {{ panic(err) }}"
        return "/* shutil.move args error */"

    def _shutil_rmtree(self, args: List[str]) -> str:
        if len(args) >= 1:
            return f"os.rmdir_all({args[0]}) or {{ panic(err) }}"
        return "/* shutil.rmtree args error */"

    def _shutil_copytree(self, args: List[str]) -> str:
        if len(args) >= 2:
            # os.cp_all(src, dst, overwrite)
            return f"os.cp_all({args[0]}, {args[1]}, true) or {{ panic(err) }}"
        return "/* shutil.copytree args error */"

    def _shutil_which(self, args: List[str]) -> str:
        if len(args) >= 1:
             return f"os.find_abs_path_of_executable({args[0]}) or {{ '' }}"
        return "''"

    def _tempfile_mkstemp(self, args: List[str]) -> str:
        # mkstemp(suffix, prefix, dir, text)
        # V: os.create_temp(pattern) -> (File, string)
        # We need to adapt arguments. V create_temp takes a pattern.
        # Minimal impl: os.create_temp('') returns (File, path)
        # We need to close the file to simulate mkstemp returning (fd, path) or similar?
        # mkstemp returns (fd, path).
        # We can construct a tuple/array or struct?
        # os.create_temp('') returns (File, string).
        # We can map it to:
        # (os.create_temp('') or { panic(err) })
        # But this returns a Result.
        # Let's emit a helper call if needed, or inline.
        # Inline:
        # (fn() (int, string) { f, p := os.create_temp('') or { panic(err) }; return f.fd, p })()
        # This is complex.
        # Simplified: os.create_temp('') or { panic(err) } returns File, string? No, just File.
        # Wait, docs say create_temp returns (File, string).
        # But V usually returns Result.
        # Let's assume `os.create_temp('') or { panic(err) }` returns `(File, string)`.
        # No, multiple return values in V must be handled.
        # `f, p := os.create_temp('') or { panic(err) }`
        # We can't put this in an expression.
        # We probably need to implement this via AST transformation or helper function injection.
        # For now, let's return a comment or best effort.
        return "/* tempfile.mkstemp() - complex mapping needed */"

    def _tempfile_mkdtemp(self, args: List[str]) -> str:
        # mkdtemp(suffix, prefix, dir)
        # V: os.mkdir_temp(prefix) returns string
        prefix = "''"
        if len(args) >= 2:
             prefix = args[1]
        return f"os.mkdir_temp({prefix}) or {{ panic(err) }}"

    def _tempfile_named_temporary_file(self, args: List[str]) -> str:
        # NamedTemporaryFile() -> file-like object
        # In V, os.create_temp('') returns (File, path).
        # If used in 'with', we want the file object.
        # But create_temp returns two values.
        # We can try to use a helper `py_named_temp_file()`
        return "py_named_temp_file()"

    def _tempfile_temporary_directory(self, args: List[str]) -> str:
        # TemporaryDirectory() -> context manager yielding path
        # In V, os.mkdir_temp('') returns path.
        # We need a struct that has .cleanup() method?
        # Or just return the path string?
        # If used in `with`, `visit_With` handles cleanup via `.close()`.
        # But TemporaryDirectory needs `.cleanup()`.
        # We might need a helper struct `PyTempDir` with `close()` method that calls `rmdir_all`.
        return "py_temp_dir()"

    def _logging_get_logger(self, args: List[str]) -> str:
        if len(args) == 1:
            return f"py_get_logger({args[0]})"
        return "py_get_logger('')"

    def _logging_basic_config(self, args: List[str]) -> str:
        return "/* logging.basicConfig ignored */"

    def _collections_defaultdict(self, args: List[str]) -> str:
        if len(args) == 1:
            factory = args[0]
            if factory == "int":
                return "map[string]int{}"
            elif factory == "list":
                # Assuming list of ints for generic list usage, or use generic array if possible?
                # V requires specific type. map[string][]int{} is a safe bet for numbers.
                return "map[string][]int{}"
            elif factory == "set":
                 return "map[string]map[int]bool{}"
        # Fallback
        return "map[string]int{}"

    def _collections_Counter(self, args: List[str]) -> str:
        if len(args) == 1:
            return f"py_counter({args[0]})"
        return "map[string]int{}"

    def _itertools_repeat(self, args: List[str]) -> str:
        if len(args) >= 2:
            return f"py_repeat({args[0]}, {args[1]})"
        return "[]int{}"

    def _itertools_count(self, args: List[str]) -> str:
        start = "0"
        step = "1"
        if len(args) >= 1:
             start = args[0]
        if len(args) >= 2:
             step = args[1]
        return f"py_count({start}, {step})"

    def _threading_lock(self, args: List[str]) -> str:
        return "sync.new_mutex()"

    def _struct_pack(self, args: List[str]) -> str:
        if len(args) < 2:
            return "/* struct.pack missing args */"
        fmt = args[0]
        # Check for string literal
        if fmt.startswith("'") and fmt.endswith("'"):
            fmt_str = fmt[1:-1]
            val = args[1]
            if fmt_str == "<I": return f"py_struct_pack_I_le(u32({val}))"
            if fmt_str == ">I": return f"py_struct_pack_I_be(u32({val}))"
            if fmt_str == "<i": return f"py_struct_pack_i_le(int({val}))"
            if fmt_str == ">i": return f"py_struct_pack_i_be(int({val}))"
            if fmt_str == "<H": return f"py_struct_pack_H_le(u16({val}))"
            if fmt_str == ">H": return f"py_struct_pack_H_be(u16({val}))"
            if fmt_str == "<h": return f"py_struct_pack_h_le(i16({val}))"
            if fmt_str == ">h": return f"py_struct_pack_h_be(i16({val}))"
            if fmt_str == "<Q": return f"py_struct_pack_Q_le(u64({val}))"
            if fmt_str == ">Q": return f"py_struct_pack_Q_be(u64({val}))"
            if fmt_str == "<q": return f"py_struct_pack_q_le(i64({val}))"
            if fmt_str == ">q": return f"py_struct_pack_q_be(i64({val}))"

        return f"py_struct_pack({', '.join(args)})"

    def _struct_unpack(self, args: List[str]) -> str:
        if len(args) < 2:
            return "/* struct.unpack missing args */"
        fmt = args[0]
        buf = args[1]
        if fmt.startswith("'") and fmt.endswith("'"):
            fmt_str = fmt[1:-1]
            if fmt_str == "<I": return f"py_struct_unpack_I_le({buf})"
            if fmt_str == ">I": return f"py_struct_unpack_I_be({buf})"
            if fmt_str == "<i": return f"py_struct_unpack_i_le({buf})"
            if fmt_str == ">i": return f"py_struct_unpack_i_be({buf})"
            if fmt_str == "<H": return f"py_struct_unpack_H_le({buf})"
            if fmt_str == ">H": return f"py_struct_unpack_H_be({buf})"
            if fmt_str == "<h": return f"py_struct_unpack_h_le({buf})"
            if fmt_str == ">h": return f"py_struct_unpack_h_be({buf})"
            if fmt_str == "<Q": return f"py_struct_unpack_Q_le({buf})"
            if fmt_str == ">Q": return f"py_struct_unpack_Q_be({buf})"
            if fmt_str == "<q": return f"py_struct_unpack_q_le({buf})"
            if fmt_str == ">q": return f"py_struct_unpack_q_be({buf})"

        return f"py_struct_unpack({', '.join(args)})"

    def _array_array(self, args: List[str]) -> str:
        if len(args) < 1:
            return "/* array.array missing args */"
        typecode = args[0]
        initializer = args[1] if len(args) > 1 else "[]"
        return f"py_array({typecode}, {initializer})"

    def _fractions_Fraction(self, args: List[str]) -> str:
        if len(args) == 2:
            return f"fractions.fraction({args[0]}, {args[1]})"
        if len(args) == 1:
            return f"py_fraction({args[0]})"
        return "fractions.fraction(0, 1)"

    def _contextlib_closing(self, args: List[str]) -> str:
        # closing(x) -> x
        if len(args) >= 1:
            return args[0]
        return "/* contextlib.closing missing args */"

    def _contextlib_nullcontext(self, args: List[str]) -> str:
        # nullcontext(x) -> x
        if len(args) >= 1:
            return args[0]
        return "0" # Default? or nothing. Python default is None.

    def _contextlib_suppress(self, args: List[str]) -> str:
        # suppress(*exceptions)
        # We map to a comment because the logic is in visit_With
        return f"/* contextlib.suppress({', '.join(args)}) */"

    def _contextlib_redirect_stdout(self, args: List[str]) -> str:
        return f"/* contextlib.redirect_stdout({', '.join(args)}) ignored */"

    def _typing_cast(self, args: List[str]) -> str:
        # We handle this directly in expressions.py now for type resolution
        return "/* typing.cast intercepted by expressions.py */"

    def _platform_python_implementation(self, args: List[str]) -> str:
        return "'V'"
