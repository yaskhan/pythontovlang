import ast
from typing import Optional
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

        # Handle defined classes and potential types
        is_potential_type = name and name[0].isupper() and not name.isupper()
        if name in getattr(self, "defined_classes", {}) or is_potential_type:
             return self._sanitize_name(name, is_type=True)

        # Check markers
        if "__py2v_gen" in name.lower():
             return name

        # Avoid prefixing local variables in SCC
        res = self._sanitize_name(name)
        
        # Local and global variable lookup
        s_name = self._to_snake_case(name)
        if name in self._local_vars_in_scope:
            res = self._sanitize_name(name)
        elif s_name in self._local_vars_in_scope:
            res = self._sanitize_name(s_name)
        elif name in getattr(self, "global_vars", set()):
            res = self._sanitize_name(name)
        elif s_name in getattr(self, "global_vars", set()):
            res = self._sanitize_name(s_name)


        # Apply narrowing if mypy type differs from base type
        if isinstance(node.ctx, ast.Load):
            try:
                narrowed_type: Optional[str] = self._guess_type(node, use_location=True)
                base_type: Optional[str] = self._guess_type(node, use_location=False)
            except TypeError:
                narrowed_type = self.type_inference.location_map.get(f"{node.lineno}:{node.col_offset}") if hasattr(node, 'lineno') and hasattr(self.type_inference, "location_map") else None
                base_type = self.type_inference.type_map.get(node.id) or self._guess_type(node)

            v_narrowed_type: Optional[str] = self._map_type(narrowed_type) if narrowed_type else None
            v_base_type: Optional[str] = self._map_type(base_type) if base_type else None

            if v_narrowed_type and v_base_type and v_narrowed_type != v_base_type:
                if v_base_type and (v_base_type.startswith("fn") or "fn(" in v_base_type):
                    return res
                if v_base_type.startswith("SumType_") or v_base_type == "Any":
                    v_base_name = v_base_type.split('.')[-1] if v_base_type else ""
                    is_named_struct = v_base_name and v_base_name[0].isupper() and not v_base_name.startswith("TupleStruct_")
                    is_generic_cast = v_narrowed_type.startswith("[]") or v_narrowed_type.startswith("TupleStruct_") or v_narrowed_type == "Any"
                    if not (is_named_struct and is_generic_cast) and v_narrowed_type not in ("none", "void", "unknown"):
                        if not ("(" in res and " as " in res):
                            res = f"({res} as {v_narrowed_type})"

        return res
