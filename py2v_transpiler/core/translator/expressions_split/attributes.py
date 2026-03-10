import ast
from ..base import TranslatorBase

class AttributesMixin(TranslatorBase):
    def visit_Attribute(self, node: ast.Attribute) -> str:
        # Check if this is a mapped constant (e.g. math.pi)
        if isinstance(node.value, ast.Name) and node.value.id in self.imported_modules:
             module_name = self.imported_modules[node.value.id]
             const_name = node.attr
             mapped = self.mapper.get_constant_mapping(module_name, const_name)
             if mapped:
                 # Add automatic V imports for the module
                 v_imports = self.mapper.get_imports(module_name)
                 if v_imports:
                     for imp in v_imports:
                         self.emitter.add_import(imp)
                 return mapped

        if node.attr == "__class__":
             obj = self.visit(node.value)
             return f"typeof({obj})"

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
        if "(" in obj and " as " in obj:
            pass
        # Apply narrowing if mypy type differs from local type mapping
        # Only do this if we can safely cast without syntax errors.
        elif isinstance(node.value, ast.Name):
            base_type = self.type_inference.type_map.get(node.value.id)
            # Find narrowed type via node location first, fall back to general guess_type
            narrowed_type = None
            if hasattr(node.value, 'lineno') and hasattr(node.value, 'col_offset'):
                loc_key = f"{node.value.id}@{node.value.lineno}:{node.value.col_offset}"
                narrowed_type = self.type_inference.type_map.get(loc_key)
            if not narrowed_type:
                narrowed_type = self._guess_type(node.value)

            # If mypy narrowed the type and it's not "int" (fallback) or generic "Any"
            if narrowed_type and base_type and narrowed_type != base_type and narrowed_type not in ("int", "Any", "void"):
                # Avoid casting to same primitive types or optionals
                if not (base_type.startswith("?") and base_type[1:] == narrowed_type):
                    # Emit an explicit cast in V: (obj as NarrowedType)
                    obj = f"({obj} as {narrowed_type})"

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
        # If receiver is a class name or its type is a class we know, check for static methods.
        target_class = None
        defined_classes = getattr(self, "defined_classes", {})
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

        # Handle SCC Attribute access: imported_module.attr -> prefix__attr
        if isinstance(node.value, ast.Name) and node.value.id in self.imported_modules:
            module_name = self.imported_modules[node.value.id]
            scc_file = next((f for f in self.scc_files if module_name.endswith(f.replace('.py', '').replace('/', '.').replace('\\', '.'))), None)
            if scc_file:
                prefix = self._get_scc_prefix(scc_file)
                return f"{prefix}__{attr_name}"

        return f"{obj}.{attr_name}"
