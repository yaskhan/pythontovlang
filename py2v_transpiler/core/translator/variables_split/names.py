import ast
from ..base import TranslatorBase


class NamesMixin(TranslatorBase):
    """Обработка имен: visit_Name"""
    
    def visit_Name(self, node: ast.Name) -> str:
        if node.id in self.name_remap:
            return self.name_remap[node.id]

        # Resolve SCC symbols
        if node.id in self.imported_symbols:
            return self.imported_symbols[node.id]

        # Name mangling for class-private attributes
        name = self._mangle_name(node.id, self.current_class)

        # Apply narrowing if mypy type or flow-inference type differs from local type mapping
        if isinstance(node.ctx, ast.Load):
            base_type = self.type_inference.type_map.get(node.id)
            # Find narrowed type via node location
            loc_key = f"{node.id}@{getattr(node, 'lineno', 0)}:{getattr(node, 'col_offset', 0)}"
            narrowed_type = self.type_inference.type_map.get(loc_key)

            if not narrowed_type:
                # Fallback to general guess_type which might use mypy location map
                # But wait, we want to AVOID infinite recursion if _guess_type calls visit_Name
                # TranslatorBase._guess_type for ast.Name does NOT call visit(node), it calls resolve_type/type_map.
                narrowed_type = self._guess_type(node)

            if narrowed_type and base_type and narrowed_type != base_type and narrowed_type not in ("Any", "void", "unknown"):
                # Special case: allow narrowing to 'int' if base was '?int'
                # Also handle 'string' vs '?string', etc.
                is_significant = False
                if base_type.startswith("?"):
                    if narrowed_type == base_type[1:]:
                        is_significant = True

                if narrowed_type not in ("int", "f64", "string", "bool"):
                    # For non-primitive types, it's likely a class narrowing
                    is_significant = True

                if is_significant:
                    sanitized = self._sanitize_name(name)
                    # For primitive types, use functional cast if it's an unwrap from optional
                    if narrowed_type in ("int", "f64", "string", "bool") and base_type.startswith("?"):
                         return f"{narrowed_type}({sanitized})"

                    # Avoid casting to same primitive types or optionals if redundant
                    if not (base_type.startswith("?") and base_type[1:] == narrowed_type):
                        return f"({sanitized} as {narrowed_type})"

        # Avoid prefixing local variables in SCC
        if name in self._local_vars_in_scope:
            return self._sanitize_name(name)

        return self._sanitize_name(name)
