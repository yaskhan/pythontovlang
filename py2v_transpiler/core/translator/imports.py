import ast
from .base import TranslatorBase

class ImportsMixin(TranslatorBase):
    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            module_name = alias.name
            as_name = alias.asname if alias.asname else module_name
            self.imported_modules[as_name] = module_name

            # Add V imports via mapper
            v_imports = self.mapper.get_imports(module_name)
            if v_imports is not None:
                for imp in v_imports:
                    self.emitter.add_import(imp)
            else:
                # If not mapped (None), import as is
                self.emitter.add_import(module_name)

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        if node.module:
            module_name = node.module

            # Suppress __future__ imports
            if module_name == "__future__":
                return

            # Add V imports
            v_imports = self.mapper.get_imports(module_name)
            if v_imports is not None:
                for imp in v_imports:
                    self.emitter.add_import(imp)
            # Else? For ImportFrom, we don't necessarily import the module if not mapped,
            # unless we need symbols from it. Python `from x import y` imports y.
            # If not mapped, we might need `import x` or `import x.y`.
            # Existing logic didn't handle `else` case for ImportFrom explicitly
            # except implicitly assuming `y` would be used.

            for alias in node.names:
                name = alias.name
                as_name = alias.asname if alias.asname else name
                self.imported_symbols[as_name] = f"{module_name}.{name}"
