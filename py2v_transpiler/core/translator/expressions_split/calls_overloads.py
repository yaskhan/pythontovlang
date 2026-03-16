"""Handling function and operator overloads."""

import ast
import re
from typing import Any, Dict, List, Optional, TYPE_CHECKING


class OverloadCallsMixin:
    """Mixin for handling overloaded function calls."""

    if TYPE_CHECKING:
        def _guess_type(self, node: ast.AST) -> str: ...
        def _map_type(
            self,
            type_str: str,
            struct_name: Optional[str] = None,
            allow_union: bool = True,
            register_sum_types: bool = True,
            is_return: bool = False
        ) -> str: ...
        def _get_factory_name(self, struct_name: str) -> str: ...
        def _get_scc_prefix(self, file_path: str) -> str: ...
        def _sanitize_name(self, name: str, is_type: bool = False) -> str: ...
        def visit(self, node: ast.AST) -> str: ...
        overloaded_signatures: Dict[str, List[Dict[str, Any]]]
        imported_modules: Dict[str, str]
        imported_symbols: Dict[str, str]

    def _handle_overloaded_function(self, node: ast.Call, func_node: ast.AST, func_name_str: str,
                                    lookup_name: str, args: list, call_sig: dict | None,
                                    is_class: bool) -> str | None:
        """Handle overloaded functions."""
        
        ov_key = lookup_name
        receiver_type = None
        
        if is_class:
            ov_key = f"{lookup_name}.__init__"
        elif isinstance(node.func, ast.Attribute):
            receiver_type = self._guess_type(node.func.value)
            if receiver_type != "Any" and not receiver_type.startswith("[]") and not receiver_type.startswith("map["):
                ov_key = f"{receiver_type}.{node.func.attr}"
        
        if ov_key not in getattr(self, "overloaded_signatures", {}):
            return None
        
        # Build type suffix from arguments
        type_suffix_parts = self._build_type_suffix(node, call_sig)
        
        # Find best match among defined overloads
        best_match_suffix = self._find_best_overload_match(ov_key, type_suffix_parts)
        
        # Handle operator overloading
        op_result = self._handle_operator_overload(func_name_str, node, func_node, args)
        if op_result:
            return op_result
        
        # Build final function name with type suffix
        if best_match_suffix:
            if is_class:
                func_name_str = f"{self._get_factory_name(lookup_name)}_{best_match_suffix}"
            else:
                func_name_str = f"{func_name_str}_{best_match_suffix}"
        elif type_suffix_parts:
            if is_class:
                func_name_str = f"{self._get_factory_name(lookup_name)}_{'_'.join(type_suffix_parts)}"
            else:
                func_name_str = f"{func_name_str}_{'_'.join(type_suffix_parts)}"
        else:
            if is_class:
                func_name_str = f"{self._get_factory_name(lookup_name)}_noargs"
            else:
                func_name_str = f"{func_name_str}_noargs"
        
        return func_name_str

    def _build_type_suffix(self, node: ast.Call, call_sig: dict | None) -> List[str]:
        """Build type suffix for overloading."""
        type_suffix_parts = []

        if call_sig and "args" in call_sig:
            # Use argument types resolved by mypy
            for arg_typ in call_sig["args"]:
                norm_typ = arg_typ.replace("builtins.", "")
                if "Literal[" in arg_typ:
                    if "'" in arg_typ or '"' in arg_typ:
                        norm_typ = "str"
                    else:
                        norm_typ = "int"
                try:
                    v_type = self._map_type(norm_typ)
                except Exception:
                    v_type = "Any"

                # Ensure we map mypy's builtins correctly
                if v_type in ("builtins.int", "builtins.str", "builtins.float", "builtins.bool"):
                    v_type = v_type.split(".")[-1]
                if norm_typ in ("int", "str", "float", "bool"):
                    v_type = {"int": "int", "str": "string", "float": "f64", "bool": "bool"}.get(norm_typ, v_type)

                clean_type = v_type.replace("?", "opt_").replace("[]", "arr_").replace("[", "_").replace("]", "").replace(".", "_")
                type_suffix_parts.append(clean_type)
        else:
            # Fallback: guess types from arguments
            for arg in node.args:
                arg_type = self._guess_type(arg)
                clean_type = arg_type.replace("?", "opt_").replace("[]", "arr_").replace("[", "_").replace("]", "").replace(".", "_")
                type_suffix_parts.append(clean_type)

        return type_suffix_parts

    def _find_best_overload_match(self, ov_key: str, type_suffix_parts: List[str]) -> str | None:
        """Find best match among overloads."""
        if ov_key not in self.overloaded_signatures:
            return None

        for sig in self.overloaded_signatures[ov_key]:
            sig_suffix_parts = []
            for arg in sig["args"]:
                sig_type = arg["type"]
                clean_sig_type = sig_type.replace("?", "opt_").replace("[]", "arr_").replace("[", "_").replace("]", "").replace(".", "_")
                sig_suffix_parts.append(clean_sig_type)

            # Exact match
            if sig_suffix_parts == type_suffix_parts:
                return "_".join(sig_suffix_parts)

        return None

    def _handle_operator_overload(self, func_name_str: str, node: ast.Call,
                                   func_node: ast.AST, args: list) -> str | None:
        """Handle operators called as methods: obj.__add__(arg)."""
        
        op_map = {
            "__add__": "+", "__sub__": "-", "__mul__": "*", "__truediv__": "/",
            "__mod__": "%", "__lt__": "<", "__le__": "<=", "__eq__": "==",
            "__ne__": "!=", "__gt__": ">", "__ge__": ">="
        }
        
        if func_name_str not in op_map:
            return None
        
        op_str = op_map[func_name_str]
        
        # If we are in obj.method(arg), then we need to restructure it to obj + arg
        if len(args) == 1 and isinstance(func_node, ast.Attribute):
            obj = self.visit(func_node.value)
            return f"{obj} {op_str} {args[0]}"
        
        return None

    def _handle_scc_call(self, node: ast.Call, func_node: ast.AST, func_name_str: str, args: list) -> str | None:
        """Handle SCC (strongly connected components) function calls."""

        # Resolve SCC Attribute calls (module.Func)
        if isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name):
            if node.func.value.id in getattr(self, 'imported_modules', {}):
                module_name_scc = self.imported_modules[node.func.value.id]
                scc_file = next((f for f in getattr(self, 'scc_files', [])
                                if module_name_scc.endswith(f.replace('.py', '').replace('/', '.').replace('\\', '.'))), None)
                if scc_file:
                    prefix = self._get_scc_prefix(scc_file)
                    func_name_scc = f"{prefix}__{self._sanitize_name(node.func.attr)}"
                    return f"{func_name_scc}({', '.join(args)})"

        # Resolve SCC direct calls (from mod import func)
        if isinstance(node.func, ast.Name) and node.func.id in getattr(self, 'imported_symbols', {}):
            full_name = self.imported_symbols[node.func.id]
            if "__" in full_name:
                return f"{full_name}({', '.join(args)})"

        return None

    def _handle_typing_assert_functions(self, node: ast.Call, func_name_str: str,
                                         original_id: str | None, args: list) -> str | None:
        """Handle typing.assert_type and typing.assert_never."""
        
        # typing.assert_type
        if func_name_str == "typing.assert_type" or (original_id == "assert_type" and func_name_str == "assert_type"):
            if len(args) >= 2:
                expr_node = node.args[0]
                type_node = node.args[1]
                expr_type = self._guess_type(expr_node)
                try:
                    type_str = ast.unparse(type_node)
                    expected_type = self._map_type(type_str)
                except Exception:
                    type_str = str(self.visit(type_node))
                    expected_type = self._map_type(type_str)
                
                if expr_type == expected_type:
                    return f"// assert_type({args[0]}, {expected_type}) passed statically"
                else:
                    return f"$compile_error('assert_type failed: expected {expected_type} but got {expr_type}')"
            return "// assert_type requires 2 arguments"
        
        # typing.assert_never
        if func_name_str == "typing.assert_never" or (original_id == "assert_never" and func_name_str == "assert_never"):
            if len(args) >= 1:
                return f"panic('assert_never reached: ${{args[0]}}')"
            return "// assert_never requires 1 argument"
        
        return None
