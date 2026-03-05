import ast
from ..base import TranslatorBase

class ContextMixin(TranslatorBase):
    """Обработка контекстных менеджеров: with, async with"""
    
    def visit_AsyncWith(self, node: ast.AsyncWith) -> None:
        # Similar logic to visit_With, but using enter/exit
        for item in node.items:
            context_expr = self.visit(item.context_expr)

            tmp_var = f"ctx_mgr_{self._zip_counter}"
            self._zip_counter += 1
            self.output.append(f"{self._indent()}{tmp_var} := {context_expr}")
            self.output.append(f"{self._indent()}defer {{ {tmp_var}.exit(none, none, none) }}")

            if item.optional_vars:
                var = self.visit(item.optional_vars)
                self.output.append(f"{self._indent()}{var} := {tmp_var}.enter()")
            else:
                self.output.append(f"{self._indent()}{tmp_var}.enter()")

        for stmt in node.body:
            self.visit(stmt)

    def visit_With(self, node: ast.With) -> None:
        for item in node.items:
            # Special handling for contextlib.nullcontext and contextlib.suppress
            # Check if context_expr is a call to these functions
            is_nullcontext = False
            is_suppress = False
            is_legacy_mgr = False # Use .close() instead of .enter()/.exit()

            if isinstance(item.context_expr, ast.Call):
                func = item.context_expr.func

                module_alias = None
                attr_name = None

                if isinstance(func, ast.Name):
                    # Direct call: nullcontext() or suppress()
                    # Check if mapped in imported_symbols
                    if func.id in self.imported_symbols:
                         full_name = self.imported_symbols[func.id]
                         if full_name == "contextlib.nullcontext": is_nullcontext = True
                         if full_name == "contextlib.suppress": is_suppress = True
                         if full_name == "contextlib.closing": is_legacy_mgr = True
                    else:
                         # Heuristic for unimported or simple usage
                         if func.id == "nullcontext": is_nullcontext = True
                         if func.id == "suppress": is_suppress = True
                         if func.id == "open": is_legacy_mgr = True
                         if func.id == "closing": is_legacy_mgr = True

                elif isinstance(func, ast.Attribute):
                    # contextlib.nullcontext
                    if isinstance(func.value, ast.Name):
                        module_alias = func.value.id
                        attr_name = func.attr

                        resolved_module = self.imported_modules.get(module_alias, module_alias)
                        if resolved_module == "contextlib":
                            if attr_name == "nullcontext": is_nullcontext = True
                            if attr_name == "suppress": is_suppress = True
                            if attr_name == "closing": is_legacy_mgr = True

            context_expr = self.visit(item.context_expr)

            if is_suppress:
                # suppress() maps to a comment via mapper, so context_expr is "/* ... */"
                # We just emit it as a statement (comment) and don't create a variable or defer
                self.output.append(f"{self._indent()}{context_expr}")
                continue

            if is_nullcontext:
                # nullcontext(x) maps to x.
                # We assign it to var if present, but do NOT defer exit()
                if item.optional_vars:
                    var = self.visit(item.optional_vars)
                    self.output.append(f"{self._indent()}{var} := {context_expr}")
                else:
                    self.output.append(f"{self._indent()}_ = {context_expr}")
                continue

            if is_legacy_mgr:
                if item.optional_vars:
                    var = self.visit(item.optional_vars)
                    self.output.append(f"{self._indent()}{var} := {context_expr}")
                    self.output.append(f"{self._indent()}defer {{ {var}.close() }}")
                else:
                    tmp_var = f"ctx_mgr_{self._zip_counter}"
                    self._zip_counter += 1
                    self.output.append(f"{self._indent()}{tmp_var} := {context_expr}")
                    self.output.append(f"{self._indent()}defer {{ {tmp_var}.close() }}")
                continue

            tmp_var = f"ctx_mgr_{self._zip_counter}"
            self._zip_counter += 1
            self.output.append(f"{self._indent()}{tmp_var} := {context_expr}")
            self.output.append(f"{self._indent()}defer {{ {tmp_var}.exit(none, none, none) }}")

            if item.optional_vars:
                var = self.visit(item.optional_vars)
                self.output.append(f"{self._indent()}{var} := {tmp_var}.enter()")
            else:
                self.output.append(f"{self._indent()}{tmp_var}.enter()")
        for stmt in node.body:
            self.visit(stmt)
