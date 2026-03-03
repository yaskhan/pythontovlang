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
                 return mapped

        if node.attr == "__class__":
             obj = self.visit(node.value)
             return f"typeof({obj})"

        if node.attr == "real":
             if self._guess_type(node.value) == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.re"
        elif node.attr == "imag":
             if self._guess_type(node.value) == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.im"

        obj = self.visit(node.value)

        # Mangling for self.__private attributes
        # We need to know if we are accessing self inside a class
        attr_name = self._sanitize_name(node.attr)
        if self.current_class and isinstance(node.value, ast.Name):
            # Checking if the receiver is 'self' is tricky because 'self' is not guaranteed name.
            # But usually it is the first arg.
            # We don't easily track variable origin here.
            # However, standard Python mangling applies to ANY attribute access inside the class method
            # if the attribute starts with __
            # Wait, python mangles `self.__x` but also `other.__x` if inside Class.
            # So we apply mangling regardless of receiver, if we are inside a class.
            attr_name = self._sanitize_name(self._mangle_name(node.attr, self.current_class))

        # Check if obj corresponds to a known function (Function Attributes)
        # obj is already visited code, e.g. "func_name".
        # We check if `obj` is in `self.function_names`.
        # Note: obj might be scoped (e.g. mod.func). We only track simple names for now.
        if obj in self.function_names:
            # Map func.attr -> func__attr
            return f"{obj}__{attr_name}"

        # Handle SCC Attribute access: imported_module.attr -> prefix__attr
        if isinstance(node.value, ast.Name) and node.value.id in self.imported_modules:
            module_name = self.imported_modules[node.value.id]
            scc_file = next((f for f in self.scc_files if module_name.endswith(f.replace('.py', '').replace('/', '.').replace('\\', '.'))), None)
            if scc_file:
                prefix = self._get_scc_prefix(scc_file)
                return f"{prefix}__{attr_name}"

        return f"{obj}.{attr_name}"
