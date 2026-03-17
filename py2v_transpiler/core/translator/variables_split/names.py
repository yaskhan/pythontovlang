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

        # Avoid prefixing local variables in SCC
        res = self._sanitize_name(name)
        if name in self._local_vars_in_scope:
            res = self._sanitize_name(name)
        elif self._to_snake_case(name) in self._local_vars_in_scope:
            res = self._sanitize_name(self._to_snake_case(name))
        elif name in getattr(self, "global_vars", set()):
            res = self._sanitize_name(name)
        elif self._to_snake_case(name) in getattr(self, "global_vars", set()):
            res = self._sanitize_name(self._to_snake_case(name))


        # Apply narrowing if mypy type differs from base type
        if isinstance(node.ctx, ast.Load):
            # Check for location-based narrowing first
            narrowed_type = None
            if hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
                loc_key = f"{node.id}@{node.lineno}:{node.col_offset}"
                narrowed_type = self.type_inference.type_map.get(loc_key)

            base_type = self.type_inference.type_map.get(node.id)

            if narrowed_type and narrowed_type not in ("int", "f64", "string", "bool", "Any", "void", "none"):
                 # Skip narrowing for functions/classes
                 if base_type and (base_type.startswith("fn") or "fn(" in base_type):
                      return res

                 # If base type is unknown or differs from narrowed, apply cast
                 if not base_type or (narrowed_type != base_type and not (base_type.startswith("?") and base_type[1:] == narrowed_type)):
                      res = f"({res} as {narrowed_type})"

        return res
