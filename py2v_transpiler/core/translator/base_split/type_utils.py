import ast
from typing import Optional, TYPE_CHECKING, Any, Dict, List, Set, Sequence


class TypeUtilsMixin:
    """Mixin for type checking utilities."""

    if TYPE_CHECKING:
        def _register_literal_enum(self, nodes: Sequence[ast.AST]) -> str: ...
        def _register_tuple_struct(self, tuple_types_str: str) -> str: ...
        def _register_sum_type(self, v_union_type: str) -> str: ...
        def _get_full_self_type(self, struct_name: Optional[str] = None) -> str: ...
        def _get_combined_generic_map(self) -> Dict[str, str]: ...
        def visit(self, node: ast.AST) -> str: ...
        def _visit_with_parens(self, parent_node: ast.AST, child_node: ast.AST, is_right_operand: bool = False) -> str: ...
        def _guess_type(self, node: ast.AST) -> str: ...
        def _get_scc_prefix(self, file_path: str) -> str: ...
        imported_symbols: Dict[str, str]
        scc_files: Set[str]
        used_builtins: Set[str]

    def _is_collection_type(self, v_type: str) -> bool:
        return (
            v_type.startswith("[]") or
            v_type.startswith("map[") or
            v_type == "string" or
            v_type == "LiteralString"
        )

    def _is_clonable_collection(self, v_type: str) -> bool:
        """Checks if a V type is a collection that requires .clone() for mutable assignment."""
        return v_type.startswith("[]") or v_type.startswith("map[")

    def _is_string_type(self, v_type: str) -> bool:
        return v_type == "string" or v_type == "LiteralString"

    def _is_numeric_type(self, v_type: str) -> bool:
        return v_type in (
            "int", "f64", "i64", "u32", "u64", "i8", "i16", "u8", "u16"
        )

    def _wrap_bool(
        self,
        node: ast.expr,
        invert: bool = False,
        parent: Optional[ast.AST] = None,
        is_right_operand: bool = False
    ) -> str:
        v_type = self._guess_type(node)

        # Determine base expression string
        if parent is not None:
            expr = self._visit_with_parens(parent, node, is_right_operand)
        else:
            expr = self.visit(node)

        if v_type.startswith("?"):
            inner_type = v_type[1:]

            if inner_type == "bool":
                inner_cond = f"!{expr}" if invert else expr
            elif self._is_collection_type(inner_type):
                op = "==" if invert else ">"
                inner_cond = f"{expr}.len {op} 0"
            elif self._is_numeric_type(inner_type):
                op = "==" if invert else "!="
                inner_cond = f"{expr} {op} 0"
            elif inner_type == "Any":
                self.used_builtins.add("py_bool")
                inner_cond = f"!py_bool({expr})" if invert else f"py_bool({expr})"
            elif inner_type == "Any":
                self.used_builtins.add("py_bool")
                inner_cond = f"!py_bool({expr})" if invert else f"py_bool({expr})"
            elif inner_type == "Any":
                self.used_builtins.add("py_bool")
                inner_cond = f"!py_bool({expr})" if invert else f"py_bool({expr})"
            elif inner_type == "Any":
                self.used_builtins.add("py_bool")
                inner_cond = f"!py_bool({expr})" if invert else f"py_bool({expr})"
            else:
                inner_cond = ""

            if invert:
                if inner_cond:
                    return f"({expr} == none || {inner_cond})"
                else:
                    return f"{expr} == none"
            else:
                if inner_cond:
                    return f"({expr} != none && {inner_cond})"
                else:
                    return f"{expr} != none"

        if self._is_collection_type(v_type):
            op = "==" if invert else ">"
            return f"{expr}.len {op} 0"

        if self._is_numeric_type(v_type):
            op = "==" if invert else "!="
            return f"{expr} {op} 0"

        if v_type == "none":
            return "true" if invert else "false"

        if v_type == "bool":
            if invert:
                dummy_not = ast.UnaryOp(op=ast.Not(), operand=node)
                child_str = self._visit_with_parens(dummy_not, node, is_right_operand=True)
                return f"!{child_str}"
            if isinstance(node, (ast.Call, ast.Name, ast.Attribute)):
                return f"{expr}"
            return expr

        if v_type == "Any":
            self.used_builtins.add("py_bool")
            if invert:
                return f"!py_bool({expr})"
            return f"py_bool({expr})"

        if invert:
            dummy_not = ast.UnaryOp(op=ast.Not(), operand=node)
            child_str = self._visit_with_parens(dummy_not, node, is_right_operand=True)
            return f"!{child_str}"

        return expr

    def _map_type(
        self,
        type_str: str,
        struct_name: Optional[str] = None,
        allow_union: bool = True,
        register_sum_types: bool = True,
        is_return: bool = False
    ) -> str:
        """
        Centralized type mapping that performs map_python_type_to_v
        followed by imported_symbols and SCC-based re-mapping.
        """
        from py2v_transpiler.models.v_types import map_python_type_to_v

        registrar = self._register_sum_type if register_sum_types else None
        lit_registrar = self._register_literal_enum

        tup_registrar = self._register_tuple_struct if register_sum_types else None

        v_type = map_python_type_to_v(
            type_str,
            self_name=self._get_full_self_type(struct_name),
            generic_map=self._get_combined_generic_map(),
            allow_union=allow_union,
            sum_type_registrar=registrar,
            literal_registrar=lit_registrar,
            tuple_registrar=tup_registrar
        )

        if "map[Any]" in v_type:
            v_type = v_type.replace("map[Any]", "map[string]")

        if is_return and v_type == "none":
            return "void"

        # Centralize LiteralString to string mapping
        if v_type == "LiteralString":
            v_type = "string"

        # Skip re-mapping for basic V types
        basic_v_types = (
            'Any', 'int', 'string', 'bool', 'void', 'none', 'f64', 'i64',
            'u32', 'u64', 'i8', 'i16', 'u8', 'u16',
            'Final', 'ClassVar', 'LiteralString', 'Self'
        )
        
        # Handle nested classes resolution
        if v_type not in basic_v_types and struct_name:
             potential_nested = f"{struct_name}_{v_type}"
             if hasattr(self, 'defined_classes') and potential_nested in self.defined_classes:
                  v_type = potential_nested

        if v_type in basic_v_types:
            return v_type

        # Adjust type for imported symbols (aliasing)
        if v_type in self.imported_symbols:
            v_type = self.imported_symbols[v_type]
        elif "." in v_type:
            # Check if it is module.Type
            parts = v_type.split(".")
            module_prefix = ".".join(parts[:-1])
            typename = parts[-1]
            # Match against SCC files
            scc_file = next(
                (
                    f
                    for f in self.scc_files
                    if module_prefix.endswith(
                        f.replace(".py", "").replace("/", ".").replace("\\", ".")
                    )
                ),
                None,
            )
            if scc_file:
                prefix = self._get_scc_prefix(scc_file)
                v_type = f"{prefix}__{typename}"

        return v_type

