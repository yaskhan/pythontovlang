import ast
from ..base import TranslatorBase

class AttributesMixin(TranslatorBase):
    def visit_Attribute(self, node: ast.Attribute) -> str:
        # Handle module attributes (mapped constants or fallback)
        if isinstance(node.value, ast.Name) and node.value.id in self.imported_modules:
            module_name = self.imported_modules[node.value.id]
            scc_file = next((f for f in self.scc_files if module_name.endswith(f.replace('.py', '').replace('/', '.').replace('\\', '.'))), None)
            if scc_file:
                prefix = self._get_scc_prefix(scc_file)
                return f'{prefix}__{node.attr}'

            # Check if this is a mapped constant or function from a module
            const_name = node.attr
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
                 return f'{v_imports[0]}.{node.attr}'

        if node.attr == "__class__":
             obj = self.visit(node.value)
             return f"typeof({obj})"

        if node.attr in ("__annotations__", "__annotate__"):
            obj = self.visit(node.value)
            # Use the same logic as get_type_hints
            obj_type = self._guess_type(node.value)
            if obj_type in getattr(self, "defined_classes", {}) or obj in getattr(self, "defined_classes", {}):
                class_name = obj if obj in getattr(self, "defined_classes", {}) else obj_type
                return f"py_get_type_hints[{class_name}]()"
            if obj in getattr(self, "function_names", set()):
                return f"{obj}__annotations__"
            return f"py_get_type_hints_generic({obj})"

        if node.attr == "__type_params__":
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

        if node.attr == "real":
             if self._guess_type(node.value) == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.re"
        elif node.attr == "imag":
             if self._guess_type(node.value) == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.im"

        obj = self.visit(node.value)

        # Avoid double casting if visit(node.value) already applied casting (via NamesMixin)
        if obj is not None and "(" in obj and " as " in obj:
            pass

        # Mangling for self.__private attributes
        # We need to know if we are accessing self inside a class
        attr_name = node.attr
        if attr_name == "__next__": attr_name = "next"
        elif attr_name == "__await__": attr_name = "await_"
        elif attr_name == "__iter__": attr_name = "iter"

        attr_name = self._sanitize_name(attr_name)
        if self.current_class and isinstance(node.value, ast.Name):
            # Checking if the receiver is 'self' is tricky because 'self' is not guaranteed name.
            # But usually it is the first arg.
            # We don't easily track variable origin here.
            # However, standard Python mangling applies to ANY attribute access inside the class method
            # if the attribute starts with __
            # Wait, python mangles `self.__x` but also `other.__x` if inside Class.
            # So we apply mangling regardless of receiver, if we are inside a class.
            attr_name = self._sanitize_name(self._mangle_name(node.attr, self.current_class))

        # Static/Class methods resolution
        # If receiver is a class name, check for class variables (constants).
        defined_classes = getattr(self, "defined_classes", {})
        if obj in defined_classes:
            defining_class = self._find_defining_class_for_class_var(obj, attr_name)
            if defining_class:
                return f"{defining_class}_{attr_name}"

        # If receiver is a class name or its type is a class we know, check for static methods.
        target_class = None
        if obj in defined_classes:
            target_class = obj
        else:
            obj_type = self._guess_type(node.value)
            if obj_type in defined_classes:
                target_class = obj_type

        if target_class:
            defining_class = self._find_defining_class_for_static_method(target_class, node.attr)
            if defining_class:
                return f"{defining_class}_{attr_name}"

            defining_class = self._find_defining_class_for_static_method(target_class, node.attr)
            if defining_class:
                return f"{defining_class}_{attr_name}"

        # Check if obj corresponds to a known function (Function Attributes)
        # obj is already visited code, e.g. "func_name".
        # We check if `obj` is in `self.function_names`.
        # Note: obj might be scoped (e.g. mod.func). We only track simple names for now.
        if obj in self.function_names:
            # Map func.attr -> func__attr
            return f"{obj}__{attr_name}"

        # Descriptor narrowing check
        # If the attribute itself has a narrowed type that's explicitly not generic,
        # and it's accessed via a standard property/descriptor pattern, we can
        # either emit an explicit cast, or rely on V's static type mapping if properties
        # are mapped accurately.
        # Since Python properties map to V struct fields (or getters if we had them),
        # if the type is explicitly narrowed from a dynamic attribute to a static type,
        # we can wrap it in a cast if needed, but usually just returning it is fine unless
        # it was typed as Any/void previously.
        # To strictly enforce the descriptor narrowing request: "if a descriptor returns a specific type, use it in V."
        # If mypy knows `m.desc` is an `int` because of `Descriptor.__get__ -> int`, we should ensure
        # that type is used if assigned or passed. We can use an explicit cast if it helps V.
        # Just checking if `type_inference` has mapped `StructName.attr_name`.
        # First, we need to know the base class name of `obj`.
        base_obj_type = self._guess_type(node.value)
        if base_obj_type and base_obj_type not in ("Any", "unknown", "void", "int", "f64", "string", "bool"):
            desc_key = f"{base_obj_type}.{node.attr}"
            narrowed_desc_type = self.type_inference.type_map.get(desc_key)
            if narrowed_desc_type and narrowed_desc_type not in ("Any", "unknown", "void"):
                attr_name = self._sanitize_name(node.attr)

                # Check if it corresponds to a known function first
                if obj in self.function_names:
                    return f"({obj}__{attr_name} as {narrowed_desc_type})"

                # Otherwise, it's a struct field access
                return f"({obj}.{attr_name} as {narrowed_desc_type})"

        if isinstance(node.value, ast.Name) and node.value.id in self.imported_modules:
            module_name = self.imported_modules[node.value.id]
            scc_file = next((f for f in self.scc_files if module_name.endswith(f.replace('.py', '').replace('/', '.').replace('\\', '.'))), None)
            if scc_file:
                return f"{prefix}__{attr_name}"

        res = f"{obj}.{attr_name}"
        
        # Apply narrowing to the result of the attribute access
        # We need to narrow the attribute itself (d.value), not the recevier (d)
        # Use location_map for the attribute node itself
        if not ("(" in res and " as " in res):
            # Get the type of the attribute (node) without location-based narrowing
            try:
                v_attr_base = self._map_type(self._guess_type(node, use_location=False))
            except TypeError:
                v_attr_base = self._map_type(self._guess_type(node))
            # Get the narrowed type of the attribute from location_map
            # Use the position of the attribute node itself
            v_attr_narrowed = None
            if hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
                loc_key = f"{node.lineno}:{node.col_offset}"
                if hasattr(self.type_inference, "location_map"):
                    narrowed = self.type_inference.location_map.get(loc_key)
                    if not narrowed:
                        # Try with stripped key or shifted key if needed
                        narrowed = self.type_inference.location_map.get(loc_key.strip())
                    
                    if narrowed:
                        v_attr_narrowed = self._map_type(narrowed)
            
            if v_attr_narrowed and v_attr_base and v_attr_narrowed != v_attr_base:
                 if v_attr_base.startswith("SumType_") or v_attr_base == "Any":
                      if v_attr_narrowed not in ("Any", "void", "unknown", "none"):
                           res = f"({res} as {v_attr_narrowed})"

        return res
