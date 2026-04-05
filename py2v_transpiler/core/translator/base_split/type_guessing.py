"""Type guessing utilities."""

import ast
from typing import TYPE_CHECKING, Any, Set, Dict, List, Union

if TYPE_CHECKING:
    from .base import TranslatorBase

# Optimization: Lifted common function name to type mappings to a module-level constant
# to avoid long if/elif chains in _guess_type_call.
_SIMPLE_CALL_TYPE_MAP = {
    "int": "int",
    "float": "f64",
    "bool": "bool",
    "len": "int",
    "print": "None",
    "input": "string",
    "open": "os.File",
    "bytearray": "[]u8",
    "memoryview": "[]u8",
    "bytes": "[]u8",
    "isinstance": "bool",
    "hasattr": "bool",
    "getattr": "bool",
    "setattr": "bool",
    "Counter": "map[string]int",
    "py_range": "[]int",
    "py_zip": "[]PyZipItem",
    "py_enumerate": "[]PyEnumerateItem",
}


class TypeGuessingMixin:
    """Mixin for guessing types from AST nodes."""

    if TYPE_CHECKING:
        defined_classes: Dict[str, Dict[str, Any]]
        type_inference: Any
        def _is_literal_string_expr(self, node: ast.AST) -> bool: ...
        def _is_string_type(self, type_str: str) -> bool: ...

    def _guess_type(self, node: ast.AST, use_location: bool = True) -> str:
        """Guess the V type from an AST node."""
        # Check location map first for high-precision results
        if use_location and hasattr(node, "lineno") and hasattr(node, "col_offset") and hasattr(self.type_inference, "location_map"):
            loc_key = (node.lineno, node.col_offset)
            if loc_key in self.type_inference.location_map:
                res = self.type_inference.location_map[loc_key]
                if res != "none":
                    return res


        if isinstance(node, ast.Constant):
            if isinstance(node.value, bool):
                return "bool"
            if isinstance(node.value, int):
                return "int"
            if isinstance(node.value, float):
                return "f64"
            if isinstance(node.value, str):
                return "string"
            if isinstance(node.value, bytes):
                return "[]u8"
            if isinstance(node.value, complex):
                return "PyComplex"
            if node.value is None:
                return "Any"
            return "int"

        elif isinstance(node, ast.Lambda):
            return self._guess_type_lambda(node)

        elif isinstance(node, ast.UnaryOp):
            if isinstance(node.op, ast.Not):
                return "bool"
            return self._guess_type(node.operand)

        elif isinstance(node, (ast.BoolOp, ast.Compare)):
            return "bool"

        elif isinstance(node, ast.Call):
            return self._guess_type_call(node)

        elif isinstance(node, (ast.List, ast.Tuple)):
            return self._guess_type_list(node)

        elif isinstance(node, ast.Set):
            return self._guess_type_set(node)

        elif isinstance(node, ast.Dict):
            return self._guess_type_dict(node)

        elif isinstance(node, ast.Name):
            return self._guess_type_name(node, use_location=use_location)

        elif isinstance(node, ast.Attribute):
            return self._guess_type_attribute(node)

        elif isinstance(node, ast.Subscript):
            return self._guess_type_subscript(node)

        elif isinstance(node, ast.BinOp):
            return self._guess_type_binop(node)

        elif isinstance(node, (ast.ListComp, ast.GeneratorExp)):
            return self._guess_type_listcomp(node)

        elif isinstance(node, ast.SetComp):
            return self._guess_type_setcomp(node)

        elif isinstance(node, ast.DictComp):
            return self._guess_type_dictcomp(node)

        return "int"

    def _guess_type_call(self, node: ast.Call) -> str:
        """Guess type for a Call node."""
        if isinstance(node.func, ast.Name):
            fid = node.func.id
            if fid in self.defined_classes:
                return fid

            # Fast-path for simple builtin/helper functions
            if fid in _SIMPLE_CALL_TYPE_MAP:
                return _SIMPLE_CALL_TYPE_MAP[fid]

            if fid == "str":
                if node.args and self._is_literal_string_expr(node.args[0]):
                    return "LiteralString"
                return "string"
            if fid in ("set", "frozenset"):
                if node.args:
                    arg_type = self._guess_type(node.args[0])
                    if arg_type.startswith("[]"):
                        return f"datatypes.Set[{arg_type[2:]}]"
                return "datatypes.Set[string]"
            if fid == "defaultdict":
                if node.args:
                    factory = ""
                    if isinstance(node.args[0], ast.Name):
                        factory = node.args[0].id
                    if factory == "int":
                        return "map[string]int"
                    elif factory == "list":
                        return "map[string][]int" # Best guess
                    elif factory == "set":
                        return "map[string]map[int]bool" # Best guess
                return "map[string]Any"
            
            if fid in ("py_sorted", "py_reversed"):
                if node.args:
                    return self._guess_type(node.args[0])
                return "[]Any"
            if fid == "py_divmod":
                if node.args:
                    return f"[]{self._guess_type(node.args[0])}"
                return "[]Any"
            if fid in ("py_os_path_split", "py_os_path_splitext"):
                return "[]string"

            # Check inferred return type
            inferred_ret = self.type_inference.type_map.get(f"{fid}@return")
            if isinstance(inferred_ret, str):
                return inferred_ret

        elif isinstance(node.func, ast.Attribute):
            if node.func.attr == "bytes":
                return "[]u8"
            if node.func.attr == "get":
                obj_type = self._guess_type(node.func.value)
                if obj_type.startswith("map["):
                    parts = obj_type.split("]", 1)
                    if len(parts) > 1:
                        return parts[1]
                return "Any"
            if (
                node.func.attr == "open" and
                isinstance(node.func.value, ast.Name) and
                node.func.value.id == "os"
            ):
                return "os.File"
            if node.func.attr in ("exists", "isfile", "isdir"):
                curr = node.func.value
                parts = [node.func.attr]
                while isinstance(curr, ast.Attribute):
                    parts.append(curr.attr)
                    curr = curr.value
                if isinstance(curr, ast.Name):
                    parts.append(curr.id)

                parts.reverse()
                full_name = ".".join(parts)
                if full_name in ("os.path.exists", "os.path.isfile", "os.path.isdir"):
                    return "bool"

                if len(parts) >= 2 and parts[-2] == "path" and parts[-1] in ("exists", "isfile", "isdir"):
                    return "bool"

        return "Any"

    def _guess_type_list(self, node: ast.AST) -> str:
        """Guess type for a List or Tuple node."""
        elts = node.elts if isinstance(node, (ast.List, ast.Tuple)) else []
        if not elts:
            return "[]Any"

        element_types: List[str] = []
        has_none = False
        for elt in elts:
            if isinstance(elt, ast.Starred):
                element_types.append("Any")
            elif isinstance(elt, ast.Constant) and elt.value is None:
                has_none = True
            elif isinstance(elt, ast.Name) and elt.id in ("None", "none"):
                has_none = True
            else:
                element_types.append(self._guess_type(elt))

        lcs = "Any"
        if element_types:
            if hasattr(self.type_inference, '_find_lcs'):
                lcs = self.type_inference._find_lcs(element_types)
            elif len(set(element_types)) == 1:
                lcs = element_types[0]

        if has_none:
            return f"[]?{lcs}"

        return f"[]{lcs}" 

    def _guess_type_set(self, node: ast.Set) -> str:
        """Guess type for a Set node."""
        if not node.elts:
            return "datatypes.Set[string]"

        element_types: Set[str] = set()
        for elt in node.elts:
            if isinstance(elt, ast.Starred):
                element_types.add("Any")
            else:
                element_types.add(self._guess_type(elt))

        if len(element_types) == 1:
            t = list(element_types)[0]
            if t == "Any":
                return "datatypes.Set[string]"
            return f"datatypes.Set[{t}]"
        return "datatypes.Set[string]"

    def _guess_type_dict(self, node: ast.Dict) -> str:
        """Guess type for a Dict node."""
        if not node.keys:
            return "map[string]Any"

        key_types: Set[str] = set()
        val_types: Set[str] = set()
        for k, v in zip(node.keys, node.values):
            if k is None:  # Unpacking **expr
                key_types.add("string")
                val_types.add("Any")
            else:
                key_types.add(self._guess_type(k))
                val_types.add(self._guess_type(v))

        k_type = "string"
        if len(key_types) == 1:
            k_type = list(key_types)[0]
        elif len(key_types) > 1:
            k_type = "Any"

        if k_type == "Any":
            k_type = "string"

        v_type = "Any"
        if len(val_types) == 1:
            v_type = list(val_types)[0]
        elif len(val_types) > 1:
            v_type = "Any"

        return f"map[{k_type}]{v_type}"

    def _guess_type_name(self, node: ast.Name, use_location: bool = True) -> str:
        """Guess type for a Name node."""
        if hasattr(self, "known_v_types"):
            actual_name = getattr(self, "name_remap", {}).get(node.id, node.id)
            if actual_name in self.known_v_types:
                return self.known_v_types[actual_name]
            if node.id in self.known_v_types:
                return self.known_v_types[node.id]

        # Check for location-based type mapping
        if use_location and hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
            loc_tuple = (node.lineno, node.col_offset)
            loc_key = (node.id, loc_tuple)
            if hasattr(self.type_inference, "type_map") and loc_key in self.type_inference.type_map:
                return self.type_inference.type_map[loc_key]

        # Check type_map by name (registered during assignment translation, e.g. x = False -> bool)
        if hasattr(self.type_inference, "type_map") and node.id in self.type_inference.type_map:
            return self.type_inference.type_map[node.id]

        # Try to resolve via type inference
        inferred = self.type_inference.resolve_type(node)
        if inferred != "void":
            return inferred
        return "int"

    def _guess_type_attribute(self, node: ast.Attribute) -> str:
        """Guess type for an Attribute node."""
        val_type = self._guess_type(node.value)
        if val_type != "Any":
            attr_key = f"{val_type}.{node.attr}"
            if hasattr(self.type_inference, "type_map") and attr_key in self.type_inference.type_map:
                return self.type_inference.type_map[attr_key]

        if isinstance(node.value, ast.Name):
            attr_name = f"{node.value.id}.{node.attr}"
            if hasattr(self.type_inference, "type_map") and attr_name in self.type_inference.type_map:
                return self.type_inference.type_map[attr_name]
        return "Any"

    def _guess_type_subscript(self, node: ast.Subscript) -> str:
        """Guess type for a Subscript node."""
        if isinstance(node.value, ast.Attribute) and isinstance(node.value.value, ast.Name):
            if node.value.value.id == "sys" and node.value.attr == "argv":
                return "string"
        elif isinstance(node.value, ast.Name):
            if node.value.id == "argv":
                return "string"
        return "Any"

    def _guess_type_binop(self, node: ast.BinOp) -> str:
        """Guess type for a BinOp node."""
        left = self._guess_type(node.left)
        right = self._guess_type(node.right)

        if isinstance(node.op, ast.Div):
            if left == "PyComplex" or right == "PyComplex":
                return "PyComplex"
            return "f64"

        # For Add/Sub/Mult/Mod/Pow, check operands
        if left.startswith("[]"):
            return left
        if right.startswith("[]"):
            return right
        if left == "LiteralString" and right == "LiteralString":
            return "LiteralString"
        if self._is_string_type(left) or self._is_string_type(right):
            return "string"
        if left == "PyComplex" or right == "PyComplex":
            return "PyComplex"
        if left == "f64" or right == "f64":
            return "f64"
        if left == "int" and right == "int":
            return "int"
        return "Any"

    def _guess_type_listcomp(self, node: Union[ast.ListComp, ast.GeneratorExp]) -> str:
        """Guess type for a ListComp or GeneratorExp node."""
        elt_type = self._guess_type(node.elt)
        if elt_type == "Any" or elt_type == "unknown":
            return "[]Any"
        return f"[]{elt_type}"

    def _guess_type_setcomp(self, node: ast.SetComp) -> str:
        """Guess type for a SetComp node."""
        elt_type = self._guess_type(node.elt)
        if elt_type == "Any" or elt_type == "unknown":
            return "datatypes.Set[string]"
        return f"datatypes.Set[{elt_type}]"

    def _guess_type_dictcomp(self, node: ast.DictComp) -> str:
        """Guess type for a DictComp node."""
        key_type = self._guess_type(node.key)
        val_type = self._guess_type(node.value)
        if key_type == "Any" or key_type == "unknown":
            key_type = "string"
        if val_type == "Any" or val_type == "unknown":
            val_type = "Any"
        return f"map[{key_type}]{val_type}"

    def _guess_type_lambda(self, node: ast.Lambda) -> str:
        """Guess the V function-type string for a Lambda node.

        Detects the i=i capture-by-value pattern and excludes those args
        from the parameter list (they become closure captures in V).
        Returns a string like 'fn(int) int' for use as array element type.
        """
        # arguments.defaults covers the LAST N args of posonlyargs + args combined.
        defaults_map: Dict[str, ast.expr] = {}
        if node.args.defaults:
            posonly = list(getattr(node.args, 'posonlyargs', []))
            positional = posonly + list(node.args.args)
            defaults_start = len(positional) - len(node.args.defaults)
            for idx, default in enumerate(node.args.defaults):
                defaults_map[positional[defaults_start + idx].arg] = default

        all_args = node.args.args
        if hasattr(node.args, "posonlyargs"):
            all_args = node.args.posonlyargs + all_args
        if hasattr(node.args, "kwonlyargs"):
            all_args = all_args + node.args.kwonlyargs

        param_types: List[str] = []
        for arg in all_args:
            # Skip i=i capture-by-value args — not parameters in V
            default_expr = defaults_map.get(arg.arg)
            if (isinstance(default_expr, ast.Name)
                    and default_expr.id == arg.arg):
                continue
            arg_type = "int"
            if hasattr(self, "type_inference") and hasattr(self.type_inference, "type_map"):
                inferred = self.type_inference.type_map.get(arg.arg)
                if inferred:
                    arg_type = inferred
            param_types.append(arg_type)

        ret_type = self._guess_type(node.body)
        if ret_type in ("void", "Any", "unknown"):
            ret_type = "int"

        params_str = ", ".join(param_types)
        return f"fn({params_str}) {ret_type}"
