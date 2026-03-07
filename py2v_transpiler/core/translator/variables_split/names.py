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

        # Sanitize V's blank identifier if it is used in Load context
        # V's _ is strictly write-only, so any read (Load) must be sanitized.
        # We also sanitize in Store context if it is NOT a simple assignment (e.g. in a list)
        # but for now let's focus on Load.
        if node.id == "_" and isinstance(node.ctx, ast.Load):
            res = "py_"

        # Apply narrowing if mypy type differs from base type
        if isinstance(node.ctx, ast.Load):
            # Check for location-based narrowing first
            narrowed_type = None
            if hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
                loc_key = f"{node.id}@{node.lineno}:{node.col_offset}"
                narrowed_type = self.type_inference.type_map.get(loc_key)

            base_type = self.type_inference.type_map.get(node.id)

            if narrowed_type and narrowed_type not in ("int", "Any", "void", "none"):
                 # If base type is unknown or differs from narrowed, apply cast
                 if not base_type or (narrowed_type != base_type and not (base_type.startswith("?") and base_type[1:] == narrowed_type)):
                      res = f"({res} as {narrowed_type})"

        return res
