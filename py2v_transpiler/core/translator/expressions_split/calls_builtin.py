"""Handling built-in functions: int, str, bool, list, dict, tuple, set, bytes."""

import ast
from typing import Any, List, Optional, TYPE_CHECKING
from py2v_transpiler.models.v_types import map_python_type_to_v


class BuiltinCallsMixin:
    if TYPE_CHECKING:
        def _guess_type(self, node: ast.AST) -> str: ...
        def _indent(self) -> str: ...
        def visit(self, node: ast.AST) -> str: ...
        current_assignment_type: Optional[str]
        output: List[str]
        emitter: Any
        _emitted_any_map_comment: bool
        used_builtins: set[str]

    def _get_full_func_name(self, node: ast.Call) -> str:
        """Get full function name (e.g., bytearray.fromhex)."""
        if isinstance(node.func, ast.Attribute):
            if isinstance(node.func.value, ast.Name):
                return f"{node.func.value.id}.{node.func.attr}"
            # For nested attributes like module.submodule.func
            parts = []
            curr: Any = node.func
            while isinstance(curr, ast.Attribute):
                parts.append(curr.attr)
                curr = curr.value
            if isinstance(curr, ast.Name):
                parts.append(curr.id)
                parts.reverse()
                return ".".join(parts)
        elif isinstance(node.func, ast.Name):
            return node.func.id
        return ""

    def _handle_builtin_type_cast(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        """Handle type casting functions: int, float, bool, str, list, dict, tuple, set, bytes."""

        # Get full function name for cases like bytearray.fromhex
        full_func_name = self._get_full_func_name(node)

        # dict()
        if func_name_str == "dict" or (original_id == "dict" and func_name_str == "py_dict"):
            v_type = self.current_assignment_type or "map[string]Any"
            if not v_type.startswith("map["):
                v_type = "map[string]Any"
            if "map[Any]" in v_type:
                v_type = v_type.replace("map[Any]", "map[string]")
                if not getattr(self, '_emitted_any_map_comment', False):
                    self.output.append(f"{self._indent()}//##LLM@@ V requires map keys to be comparable types (like string, int). 'Any' was used as a map key in Python, which has been fallback-mapped to 'string'. Please review and manually adjust the map key type and its usage if necessary.")
                    self._emitted_any_map_comment = True

            if len(args) == 0 and not node.keywords:
                return f"{v_type}{{}}"

            # Handle dict([("x", 10)]) -> py_dict_from_pairs
            if len(args) == 1 and not node.keywords:
                self.used_builtins.add("py_dict_from_pairs")
                return f"py_dict_from_pairs<{v_type}>({args[0]})"

            # Handle dict(a=1, b=2) or dict(other, a=1)
            if node.keywords:
                kw_pairs = []
                for kw in node.keywords:
                    if kw.arg:
                        val = self.visit(kw.value)
                        kw_pairs.append(f"'{kw.arg}': {val}")
                kwargs_dict = f"{{{', '.join(kw_pairs)}}}"
                if len(args) == 0:
                    return kwargs_dict
                else:
                    self.used_builtins.add("py_dict_update")
                    # Create a copy and update it
                    return f"py_dict_update(mut {v_type}({args[0]}).clone(), {kwargs_dict})"

            return f"{v_type}({', '.join(args)})"
        
        # dict.fromkeys()
        elif full_func_name == "dict.fromkeys":
            v_type = self.current_assignment_type or "map[string]Any"
            if not v_type.startswith("map["):
                v_type = "map[string]Any"
            self.used_builtins.add("py_dict_fromkeys")
            val = args[1] if len(args) == 2 else "none"
            return f"py_dict_fromkeys<{v_type}>({args[0]}, {val})"

        # list()
        elif func_name_str == "list" or (original_id == "list" and func_name_str == "py_list"):
            v_type = self.current_assignment_type or "[]Any"
            if not v_type.startswith("[]"):
                v_type = "[]Any"
            if len(args) == 0:
                return f"{v_type}{{}}"
            return f"{v_type}({', '.join(args)})"
        
        # tuple()
        elif func_name_str == "tuple" or (original_id == "tuple" and func_name_str == "py_tuple"):
            v_type = self.current_assignment_type or "[]Any"
            if not v_type.startswith("["):
                v_type = "[]Any"
            if len(args) == 0:
                return f"{v_type}{{}}"
            return f"{v_type}({', '.join(args)})"
        
        # set()
        elif func_name_str == "set" or (original_id == "set" and func_name_str == "py_set"):
            v_type = self.current_assignment_type or "map[string]bool"
            if not v_type.startswith("map["):
                v_type = "map[string]bool"
            if "map[Any]" in v_type:
                v_type = v_type.replace("map[Any]", "map[string]")
                if not getattr(self, '_emitted_any_map_comment', False):
                    self.output.append(f"{self._indent()}//##LLM@@ V requires map keys to be comparable types (like string, int). 'Any' was used as a map key in Python, which has been fallback-mapped to 'string'. Please review and manually adjust the map key type and its usage if necessary.")
                    self._emitted_any_map_comment = True
            if len(args) == 0:
                return f"{v_type}{{}}"
            return f"{v_type}({', '.join(args)})"
        
        # int()
        elif func_name_str == "int" or (original_id == "int" and func_name_str == "py_int"):
            if len(args) == 0:
                return "0"
            elif len(args) == 1:
                arg_type = self._guess_type(node.args[0])
                if arg_type == "string":
                    return f"{args[0]}.int()"
                return f"int({args[0]})"
            elif len(args) == 2:
                # E.g. int('ff', 16) - V has strconv.parse_int
                self.emitter.add_import("strconv")
                return f"int(strconv.parse_int({args[0]}, {args[1]}, 32) or {{ 0 }})"
        
        # float()
        elif func_name_str == "float" or (original_id == "float" and func_name_str == "py_float"):
            if len(args) == 1:
                arg_type = self._guess_type(node.args[0])
                if arg_type == "string":
                    return f"{args[0]}.f64()"
                return f"f64({args[0]})"
            return "0.0"
        
        # bool()
        elif func_name_str == "bool" or (original_id == "bool" and func_name_str == "py_bool"):
            if len(args) == 1:
                arg_type = self._guess_type(node.args[0])
                if arg_type == "int":
                    return f"({args[0]} != 0)"
                if arg_type == "string":
                    return f"({args[0]} != '')"
                if arg_type.startswith("[]"):
                    return f"({args[0]}.len > 0)"
                return f"py_bool({args[0]})"
            return "false"
        
        # str()
        elif func_name_str == "str" or (original_id == "str" and func_name_str == "py_str"):
            if len(args) == 1:
                return f"{args[0]}.str()"
            return "''"

        # repr()
        elif original_id == "repr" or (original_id == "repr" and func_name_str == "py_repr"):
            self.used_builtins.add("py_repr")
            if len(args) == 1:
                return f"py_repr({args[0]})"
            return "''"

        # ascii()
        elif original_id == "ascii" or (original_id == "ascii" and func_name_str == "py_ascii"):
            self.used_builtins.add("py_ascii")
            if len(args) == 1:
                return f"py_ascii({args[0]})"
            return "''"

        # format()
        elif original_id == "format" or (original_id == "format" and func_name_str == "py_format"):
            self.used_builtins.add("py_format")
            if len(args) == 1:
                return f"py_format({args[0]}, '')"
            elif len(args) == 2:
                return f"py_format({args[0]}, {args[1]})"
            return "''"
        
        # bytes() / bytearray()
        elif func_name_str in ("bytes", "bytearray"):
            if len(args) == 0:
                return "[]u8{}"
            elif len(args) >= 1:
                arg_type = self._guess_type(node.args[0])
                if arg_type == "int":
                    return f"[]u8{{len: {args[0]}}}"
                if arg_type == "string":
                    return f"{args[0]}.bytes()"
                # Ensure a copy is made for buffer-like or list-like arguments
                return f"{args[0]}.clone()"
            return "[]u8{}"

        # bytes.fromhex() / bytearray.fromhex()
        elif full_func_name in ("bytes.fromhex", "bytearray.fromhex"):
            self.emitter.add_import("encoding.hex")
            return f"hex.decode({args[0]}) or {{ []u8{{}} }}"

        # memoryview()
        elif func_name_str == "memoryview":
            if len(args) >= 1:
                return f"{args[0]}"
            return "[]u8{}"
        
        return None
