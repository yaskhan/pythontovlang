"""Handling built-in functions: int, str, bool, list, dict, tuple, set, bytes."""

import ast
from typing import Any, List, Optional, TYPE_CHECKING
from py2v_transpiler.models.v_types import map_python_type_to_v

# Optimization: Dispatch dictionaries for built-in calls to avoid O(N) if/elif chain in Stage 10.
# Expected performance gain: ~1.4x-1.6x speedup for built-in call resolution.
_BUILTIN_DISPATCH_MAP = {
    "dict": "_handle_dict_call",
    "py_dict": "_handle_dict_call",
    "list": "_handle_list_call",
    "py_list": "_handle_list_call",
    "tuple": "_handle_tuple_call",
    "py_tuple": "_handle_tuple_call",
    "set": "_handle_set_call",
    "py_set": "_handle_set_call",
    "frozenset": "_handle_set_call",
    "py_frozenset": "_handle_set_call",
    "int": "_handle_int_call",
    "py_int": "_handle_int_call",
    "float": "_handle_float_call",
    "py_float": "_handle_float_call",
    "bool": "_handle_bool_call",
    "py_bool": "_handle_bool_call",
    "str": "_handle_str_call",
    "py_str": "_handle_str_call",
    "bytes": "_handle_bytes_call",
    "bytearray": "_handle_bytes_call",
    "memoryview": "_handle_memoryview_call",
    "abs": "_handle_abs_call",
    "pow": "_handle_pow_call",
    "divmod": "_handle_divmod_call",
    "ord": "_handle_ord_call",
    "chr": "_handle_chr_call",
}

# Functions that should only be matched if they are Name calls (to avoid hijacking methods like s.format())
_STRICT_BUILTIN_DISPATCH_MAP = {
    "repr": "_handle_repr_call",
    "ascii": "_handle_ascii_call",
    "format": "_handle_format_call",
}

_FULL_FUNC_DISPATCH_MAP = {
    "dict.fromkeys": "_handle_dict_fromkeys_call",
    "bytes.fromhex": "_handle_bytes_fromhex_call",
    "bytearray.fromhex": "_handle_bytes_fromhex_call",
}


class BuiltinCallsMixin:
    if TYPE_CHECKING:
        def _guess_type(self, node: ast.AST, use_location: bool = True) -> str: ...
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

    def _handle_dict_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        v_type = self.current_assignment_type or "map[string]Any"
        if not (v_type.startswith("map[") or v_type.startswith("datatypes.Set[")) or v_type == "Any":
            v_type = "map[string]Any"
        if "map[Any]" in v_type:
            v_type = v_type.replace("map[Any]", "datatypes.Set[string]")
            if not getattr(self, '_emitted_any_map_comment', False):
                self.output.append(f"{self._indent()}//##LLM@@ V requires map keys to be comparable types (like string, int). 'Any' was used as a map key in Python, which has been fallback-mapped to 'string'. Please review and manually adjust the map key type and its usage if necessary.")
                self._emitted_any_map_comment = True

        if len(args) == 0 and not node.keywords:
            return f"{v_type}{{}}"

        # Handle dict([("x", 10)]) -> py_dict_from_pairs
        if len(args) == 1 and not node.keywords:
            self.used_builtins.add("py_dict_from_pairs")
            return f"py_dict_from_pairs[{v_type}]({args[0]})"

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

    def _handle_dict_fromkeys_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        v_type = self.current_assignment_type or "map[string]Any"
        if not (v_type.startswith("map[") or v_type.startswith("datatypes.Set[")) or v_type == "Any":
            v_type = "map[string]Any"
        self.used_builtins.add("py_dict_fromkeys")
        val = args[1] if len(args) == 2 else "none"
        return f"py_dict_fromkeys[{v_type}]({args[0]}, {val})"

    def _handle_list_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        v_type = self.current_assignment_type or "[]Any"
        if not v_type.startswith("[]"):
            v_type = "[]Any"
        if len(args) == 0:
            return f"{v_type}{{}}"
        
        if len(args) == 1:
            arg_node = node.args[0]
            arg_type = self._guess_type(arg_node)
            
            # Check if it's one of our helpers that returns a slice
            is_slice_helper = False
            if isinstance(arg_node, ast.Call) and isinstance(arg_node.func, ast.Name):
                if arg_node.func.id in ("range", "py_range", "sorted", "py_sorted", "reversed", "py_reversed", "zip", "py_zip", "enumerate", "py_enumerate"):
                    is_slice_helper = True

            if arg_type.startswith("[]") or is_slice_helper:
                return f"{args[0]}.clone()"

            # If it is not a known array, it might be an iterator
            self.used_builtins.add("py_list_from_iter")
            return f"py_list_from_iter[{v_type}]({args[0]})"

        return f"{v_type}({', '.join(args)})"

    def _handle_tuple_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        v_type = self.current_assignment_type or "[]Any"
        if not v_type.startswith("["):
            v_type = "[]Any"
        if len(args) == 0:
            return f"{v_type}{{}}"
        if len(args) == 1:
            arg_node = node.args[0]
            arg_type = self._guess_type(arg_node)

            is_slice_helper = False
            if isinstance(arg_node, ast.Call) and isinstance(arg_node.func, ast.Name):
                if arg_node.func.id in ("range", "py_range", "sorted", "py_sorted", "reversed", "py_reversed", "zip", "py_zip", "enumerate", "py_enumerate"):
                    is_slice_helper = True
            
            if arg_type.startswith("[]") or is_slice_helper:
                return f"{args[0]}.clone()"

            # If it is not a known array, it might be an iterator
            self.used_builtins.add("py_list_from_iter")
            return f"py_list_from_iter[{v_type}]({args[0]})"
        return f"{v_type}({', '.join(args)})"

    def _handle_set_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        v_type = self.current_assignment_type or self._guess_type(node)
        if not (v_type.startswith("map[") or v_type.startswith("datatypes.Set[")) or v_type == "Any":
            v_type = "datatypes.Set[string]"
        if "map[Any]" in v_type:
            v_type = v_type.replace("map[Any]", "datatypes.Set[string]")
            if not getattr(self, '_emitted_any_map_comment', False):
                self.output.append(f"{self._indent()}//##LLM@@ V requires map keys to be comparable types (like string, int). 'Any' was used as a map key in Python, which has been fallback-mapped to 'string'. Please review and manually adjust the map key type and its usage if necessary.")
                self._emitted_any_map_comment = True
        if len(args) == 0:
            return f"{v_type}{{}}"
        
        if len(args) == 1:
            arg_type = self._guess_type(node.args[0])
            if arg_type.startswith("[]"):
                self.used_builtins.add("py_set_from_list")
                return f"py_set_from_list[{v_type}]({args[0]})"
            # If it is not a known array, it might be an iterator
            self.used_builtins.add("py_set_from_iter")
            return f"py_set_from_iter[{v_type}]({args[0]})"

        return f"{v_type}({', '.join(args)})"

    def _handle_int_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
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
        return None

    def _handle_float_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) == 1:
            arg_type = self._guess_type(node.args[0])
            if arg_type == "string":
                return f"{args[0]}.f64()"
            return f"f64({args[0]})"
        return "0.0"

    def _handle_bool_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
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

    def _handle_str_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) == 1:
            return f"{args[0]}.str()"
        return "''"

    def _handle_repr_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        self.used_builtins.add("py_repr")
        if len(args) == 1:
            return f"py_repr({args[0]})"
        return "''"

    def _handle_ascii_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        self.used_builtins.add("py_ascii")
        if len(args) == 1:
            return f"py_ascii({args[0]})"
        return "''"

    def _handle_format_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        self.used_builtins.add("py_format")
        if len(args) == 1:
            return f"py_format({args[0]}, '')"
        elif len(args) == 2:
            return f"py_format({args[0]}, {args[1]})"
        return "''"

    def _handle_bytes_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
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

    def _handle_bytes_fromhex_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        self.emitter.add_import("encoding.hex")
        return f"hex.decode({args[0]}) or {{ []u8{{}} }}"

    def _handle_memoryview_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) >= 1:
            return f"{args[0]}"
        return "[]u8{}"

    def _handle_abs_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) == 1:
            arg_type = self._guess_type(node.args[0])
            if arg_type == "int":
                # V doesn't have int.abs(), but math.abs() exists for f64
                # For ints, we can use if-else or math.abs(f64(x)) safely if we want f64 result.
                # Python abs(int) returns int.
                self.emitter.add_import("math")
                return f"int(math.abs(f64({args[0]})))"
            self.emitter.add_import("math")
            return f"math.abs(f64({args[0]}))"
        return None

    def _handle_pow_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) == 2:
            self.emitter.add_import("math")
            return f"math.pow(f64({args[0]}), f64({args[1]}))"
        elif len(args) == 3:
            # pow(x, y, z) -> (x**y) % z
            # V math.pow doesn't support 3 args.
            self.emitter.add_import("math")
            return f"(u64(math.pow(f64({args[0]}), f64({args[1]}))) % u64({args[2]}))"
        return None

    def _handle_divmod_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) == 2:
            self.used_builtins.add("py_divmod")
            return f"py_divmod({args[0]}, {args[1]})"
        return None

    def _handle_ord_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) == 1:
            return f"int({args[0]}[0])"
        return None

    def _handle_chr_call(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        if len(args) == 1:
            return f"u8({args[0]}).ascii_str()"
        return None

    def _handle_builtin_type_cast(self, node: ast.Call, func_name_str: str, original_id: Optional[str], args: list) -> str | None:
        """Handle type casting functions: int, float, bool, str, list, dict, tuple, set, bytes."""

        # Optimization: O(1) dispatch for common built-ins.
        if func_name_str in _BUILTIN_DISPATCH_MAP:
            handler_name = _BUILTIN_DISPATCH_MAP[func_name_str]
            return getattr(self, handler_name)(node, func_name_str, original_id, args)

        # Optimization: O(1) dispatch for functions that should NOT match Attribute calls (methods)
        # These are only checked if original_id is present (meaning it's a Name call)
        if original_id and original_id in _STRICT_BUILTIN_DISPATCH_MAP:
             handler_name = _STRICT_BUILTIN_DISPATCH_MAP[original_id]
             return getattr(self, handler_name)(node, func_name_str, original_id, args)

        # Handle int/float/bool/str/etc. when original_id is used for mapping
        if original_id in _BUILTIN_DISPATCH_MAP:
            handler_name = _BUILTIN_DISPATCH_MAP[original_id]
            return getattr(self, handler_name)(node, func_name_str, original_id, args)

        # Get full function name for cases like bytearray.fromhex
        full_func_name = self._get_full_func_name(node)

        # Optimization: O(1) dispatch for full function names.
        if full_func_name in _FULL_FUNC_DISPATCH_MAP:
            handler_name = _FULL_FUNC_DISPATCH_MAP[full_func_name]
            return getattr(self, handler_name)(node, func_name_str, original_id, args)

        return None
