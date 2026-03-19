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
        elif self._to_snake_case(name) in self._local_vars_in_scope and name not in getattr(self, "defined_classes", {}):
            res = self._sanitize_name(self._to_snake_case(name))
        elif name in getattr(self, "global_vars", set()):
            res = self._sanitize_name(name)
        elif self._to_snake_case(name) in getattr(self, "global_vars", set()) and name not in getattr(self, "defined_classes", {}):
            res = self._sanitize_name(self._to_snake_case(name))


        # Apply narrowing if mypy type differs from base type
        if isinstance(node.ctx, ast.Load):
            # Check for location-based narrowing first
            narrowed_type = None
            if hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
                loc_key = f"{node.id}@{node.lineno}:{node.col_offset}"
                narrowed_type = self.type_inference.type_map.get(loc_key)

            base_type = self.type_inference.type_map.get(node.id)
            if not base_type:
                base_type = self._guess_type(node)

            if narrowed_type:
                v_narrowed_type = self._map_type(narrowed_type)
                v_base_type = self._map_type(base_type) if base_type else None

                if v_narrowed_type not in ("int", "f64", "string", "bool", "Any", "void", "none", "unknown"):
                    # Skip narrowing for functions/classes
                    if v_base_type and (v_base_type.startswith("fn") or "fn(" in v_base_type):
                        return res

                    # If base type is unknown or differs from narrowed, apply cast
                    if not v_base_type or (v_narrowed_type != v_base_type and not (v_base_type.startswith("?") and v_base_type[1:] == v_narrowed_type)):
                        # Special case: don't cast from a named struct (NamedTuple/Class) 
                        # to a generic collection/TupleStruct or Any.
                        v_base_name = v_base_type.split('.')[-1] if v_base_type else ""
                        is_named_struct = v_base_name and v_base_name[0].isupper() and not v_base_name.startswith("TupleStruct_")
                        is_generic_cast = v_narrowed_type.startswith("[]") or v_narrowed_type.startswith("TupleStruct_") or v_narrowed_type == "Any"
                        
                        if not (is_named_struct and is_generic_cast):
                            res = f"({res} as {v_narrowed_type})"

        return res
