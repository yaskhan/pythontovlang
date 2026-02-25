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
                "time": "time.now().unix",
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
            "os": ["os"],
            "re": ["regex"],
            "shutil": ["os"],
            "unittest": [], # No import needed in V if we translate to assert
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
