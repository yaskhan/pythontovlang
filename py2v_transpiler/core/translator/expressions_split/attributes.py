import ast
from ..base import TranslatorBase

class AttributesMixin(TranslatorBase):
    def visit_Attribute(self, node: ast.Attribute) -> str:
        # Optimization: Hoisted frequently accessed attributes and cached expensive type guesses.
        imported_modules = self.imported_modules
        defined_classes = getattr(self, "defined_classes", {})
        attr_name = node.attr

        # Handle module attributes (mapped constants or fallback)
        if isinstance(node.value, ast.Name) and node.value.id in imported_modules:
            module_name = imported_modules[node.value.id]
            scc_file = next((f for f in self.scc_files if module_name.endswith(f.replace('.py', '').replace('/', '.').replace('\\', '.'))), None)
            if scc_file:
                prefix = self._get_scc_prefix(scc_file)
                return f'{prefix}__{attr_name}'

            # Check if this is a mapped constant or function from a module
            const_name = attr_name
            mapped = self.mapper.get_constant_mapping(module_name, const_name)
            if mapped:
                 # Add automatic V imports for the module
                 v_imports = self.mapper.get_imports(module_name)
                 if v_imports:
                     for imp in v_imports:
                         self.emitter.add_import(imp)
                 return mapped

            # Fallback for unmapped attributes of a mapped module (e.g. random.seed)
            v_imports = self.mapper.get_imports(module_name)
            if v_imports and len(v_imports) == 1 and v_imports[0] != module_name:
                 return f'{v_imports[0]}.{attr_name}'

        if attr_name == "__class__":
             obj = self.visit(node.value)
             return f"typeof({obj})"

        if attr_name in ("__annotations__", "__annotate__"):
            obj = self.visit(node.value)
            # Use the same logic as get_type_hints
            obj_type_guess = self._guess_type(node.value)
            if obj_type_guess in defined_classes or obj in defined_classes:
                class_name = obj if obj in defined_classes else obj_type_guess
                return f"py_get_type_hints[{class_name}]()"
            if obj in getattr(self, "function_names", set()):
                return f"{obj}__annotations__"
            return f"py_get_type_hints_generic({obj})"

        if attr_name == "__type_params__":
            obj = self.visit(node.value)
            # obj could be ClassName, ClassName[int], or a function name.
            # We strip generic arguments if any to get the base name.
            base_name = obj
            if "[" in obj:
                base_name = obj[:obj.find("[")]

            if base_name in self.type_params_map:
                params = self.type_params_map[base_name]
                if not params:
                    return "[]string{}"
                params_v = ", ".join(f"'{p}'" for p in params)
                return f"[{params_v}]"
            return "[]string{}"

        # Cache type guess for node.value as it is used multiple times below.
        obj_type_guess = self._guess_type(node.value)

        if attr_name == "real":
             if obj_type_guess == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.re"
        elif attr_name == "imag":
             if obj_type_guess == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.im"

        obj = self.visit(node.value)

        # Avoid double casting if visit(node.value) already applied casting (via NamesMixin)
        if obj is not None and "(" in obj and " as " in obj:
            pass

        # Mangling for self.__private attributes
        # We need to know if we are accessing self inside a class
        if attr_name == "__next__": attr_name = "next"
        elif attr_name == "__await__": attr_name = "await_"
        elif attr_name == "__iter__": attr_name = "iter"

        # Apply mangling regardless of receiver, if we are inside a class.
        if self.current_class:
            attr_name = self._mangle_name(attr_name, self.current_class)
        
        attr_name = self._sanitize_name(attr_name)

        # Static/Class methods resolution
        # If receiver is a class name, check for class variables (via meta singleton).
        obj_base = obj.split('[')[0] # handle ClassName[T]
        if obj_base in defined_classes:
            defining_class = self._find_defining_class_for_class_var(obj_base, attr_name)
            if defining_class:
                return f"{self._to_snake_case(defining_class)}_meta.{attr_name}"

        # If receiver is a class name or its type is a class we know, check for static methods or class variables.
        target_class = None
        if obj_base in defined_classes:
            target_class = obj_base
        elif obj_type_guess in defined_classes:
            target_class = obj_type_guess

        if target_class:
            # Check for class variable access on instance or class receiver
            defining_class_var = self._find_defining_class_for_class_var(target_class, attr_name)
            if defining_class_var:
                return f"{self._to_snake_case(defining_class_var)}_meta.{attr_name}"

            defining_class = self._find_defining_class_for_static_method(target_class, attr_name)
            if defining_class:
                return f"{defining_class}_{attr_name}"

        # Check if obj corresponds to a known function (Function Attributes)
        if obj in self.function_names:
            # Map func.attr -> func__attr
            return f"{obj}__{attr_name}"

        # Descriptor narrowing check
        if obj_type_guess and obj_type_guess not in ("Any", "unknown", "void", "int", "f64", "string", "bool"):
            desc_key = f"{obj_type_guess}.{attr_name}"
            narrowed_desc_type = self.type_inference.type_map.get(desc_key)
            if narrowed_desc_type and narrowed_desc_type not in ("Any", "unknown", "void"):
                # Check if it corresponds to a known function first
                if obj in self.function_names:
                    return f"({obj}__{attr_name} as {narrowed_desc_type})"

                # Otherwise, it's a struct field access
                return f"({obj}.{attr_name} as {narrowed_desc_type})"

        res = f"{obj}.{attr_name}"
        
        # Apply narrowing to the result of the attribute access
        if not isinstance(node.ctx, ast.Store) and not ("(" in res and " as " in res):
            try:
                v_attr_base = self._map_type(self._guess_type(node, use_location=False))
            except TypeError:
                v_attr_base = self._map_type(self._guess_type(node))
            
            v_attr_narrowed = None
            if hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
                lineno, col_offset = node.lineno, node.col_offset
                if hasattr(self.type_inference, "location_map"):
                    # Optimization: Use tuple key for faster lookup, with string fallback for compatibility.
                    loc_map = self.type_inference.location_map
                    loc_tuple = (lineno, col_offset)
                    narrowed = loc_map.get(loc_tuple)
                    if not narrowed:
                        loc_key = f"{lineno}:{col_offset}"
                        narrowed = loc_map.get(loc_key)
                    
                    if narrowed:
                        v_attr_narrowed = self._map_type(narrowed)
            
            if v_attr_narrowed and v_attr_base and v_attr_narrowed != v_attr_base:
                 if v_attr_base.startswith("SumType_") or v_attr_base == "Any":
                      if v_attr_narrowed not in ("Any", "void", "unknown", "none"):
                           res = f"({res} as {v_attr_narrowed})"

        return res
