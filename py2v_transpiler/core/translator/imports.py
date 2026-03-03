import ast
from .base import TranslatorBase

class ImportsMixin(TranslatorBase):
    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            module_name = alias.name

            # Skip imports if they are within the same SCC (same V package)
            # Map the imported module name to its SCC prefix for cross-file references
            scc_file = next((f for f in self.scc_files if module_name.endswith(f.split('.')[0])), None)
            if scc_file:
                # We don't need a V import, but we need to track that names from this module
                # are available in the current namespace (package-level).
                # However, top-level names in that file are now prefixed.
                # So we mark this module in imported_modules to handle Attribute access.
                as_name = alias.asname if alias.asname else module_name
                self.imported_modules[as_name] = module_name

                # If it's a 'from ... import *' or similar, we'd need more logic.
                # But for 'import mod', we just skip.
                continue

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

            # Skip if module is in the same SCC
            scc_file = next((f for f in self.scc_files if module_name.endswith(f.split('.')[0])), None)
            if scc_file:
                prefix = self._get_scc_prefix(scc_file)
                for alias in node.names:
                    name = alias.name
                    as_name = alias.asname if alias.asname else name
                    # The symbol is actually named 'prefix__name' in the flattened module
                    self.imported_symbols[as_name] = f"{prefix}__{name}"
                return

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
        elif node.level > 0:
            # Relative import: from . import x
            # Since we don't know the full package context, we can't fully resolve it to a V module.
            # But we can try to emit it as a local import or assume it maps to current module.
            # V doesn't have "from . import x" syntax, imports are package-level.
            # Best effort: ignored or emit TODO.

            # If we import a submodule: from . import submodule
            # In V: import submodule (if in same folder and submodule is a folder)
            # or nothing if it's just another file in the same module.
            # Let's map it to local symbols if names are provided.

            for alias in node.names:
                name = alias.name
                as_name = alias.asname if alias.asname else name
                # Just mark as imported symbol without prefix, assuming it's in the same scope/package
                self.imported_symbols[as_name] = name
                # Also try to import it if it looks like a module
                self.emitter.add_import(name)
