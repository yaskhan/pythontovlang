import ast
from .base import TranslatorBase

class ControlFlowMixin(TranslatorBase):
    def visit_If(self, node: ast.If) -> None:
        # Check for if __name__ == "__main__":
        if isinstance(node.test, ast.Compare):
            if (isinstance(node.test.left, ast.Name) and node.test.left.id == "__name__" and
                len(node.test.comparators) == 1 and isinstance(node.test.comparators[0], ast.Constant) and
                node.test.comparators[0].value == "__main__"):
                self.output.append(f"{self._indent()}// if __name__ == '__main__':")
                for stmt in node.body:
                    self.visit(stmt)
                return

        # Check for walrus operator
        self._walrus_assignments = []
        test_expr = self.visit(node.test)

        if self._walrus_assignments:
             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")
             self._walrus_assignments = []

        self.output.append(f"{self._indent()}if {test_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1

        if node.orelse:
            if len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If):
                # elif case
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                self.visit(node.orelse[0])
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
            else:
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                for stmt in node.orelse:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
        else:
            self.output.append(f"{self._indent()}}}")

    def visit_While(self, node: ast.While) -> None:
        self._walrus_assignments = []
        test_expr = self.visit(node.test)

        if self._walrus_assignments:
             # Found walrus! Transform loop.
             self.output.append(f"{self._indent()}for {{")
             self._indent_level += 1

             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")

             self.output.append(f"{self._indent()}if !({test_expr}) {{ break }}")
             self._walrus_assignments = []

             for stmt in node.body:
                 self.visit(stmt)

             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")
        else:
             # Normal while
             self.output.append(f"{self._indent()}for {test_expr} {{")
             self._indent_level += 1
             for stmt in node.body:
                 self.visit(stmt)
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")

    def visit_For(self, node: ast.For) -> None:
        # Check if iterating over generator
        iter_node = node.iter
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name):
            if self.coroutine_handler.is_generator(iter_node.func.id):
                 # Generate setup
                 ch_name = self.coroutine_handler.get_temp_channel_name()
                 yield_type = self.coroutine_handler.get_generator_type(iter_node.func.id)
                 self.output.append(f"{self._indent()}{ch_name} := chan {yield_type}{{cap: 0}}")

                 # Call spawn
                 # Construct args
                 # node.iter is Call(func, args, keywords)
                 # We need to inject ch_name as first arg
                 func_name = iter_node.func.id
                 # self.visit(node.iter.args) ?
                 spawn_args = [ch_name] + [str(self.visit(a)) for a in iter_node.args]
                 call_str = f"spawn {func_name}({', '.join(spawn_args)})"
                 self.output.append(f"{self._indent()}{call_str}")

                 # Now loop over channel
                 target = self.visit(node.target)
                 self.output.append(f"{self._indent()}for {target} in {ch_name} {{")
                 self._indent_level += 1
                 for stmt in node.body:
                     self.visit(stmt)
                 self._indent_level -= 1
                 self.output.append(f"{self._indent()}}}")
                 return

        # Zip handling
        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name) and node.iter.func.id == "zip":
            zip_args = node.iter.args
            if len(zip_args) == 2:
                self._zip_counter += 1
                zip_id = self._zip_counter
                it1 = self.visit(zip_args[0])
                it2 = self.visit(zip_args[1])
                var_it1 = f"_zip_it1_{zip_id}"
                var_it2 = f"_zip_it2_{zip_id}"
                var_i = f"_i_{zip_id}"
                var_v1 = f"_v1_{zip_id}"
                var_v2 = f"_v2_{zip_id}"
                self.output.append(f"{self._indent()}{var_it1} := {it1}")
                self.output.append(f"{self._indent()}{var_it2} := {it2}")
                self.output.append(f"{self._indent()}for {var_i}, {var_v1} in {var_it1} {{")
                self._indent_level += 1
                self.output.append(f"{self._indent()}if {var_i} >= {var_it2}.len {{ break }}")
                self.output.append(f"{self._indent()}{var_v2} := {var_it2}[{var_i}]")
                if isinstance(node.target, ast.Tuple) and len(node.target.elts) == 2:
                    t1 = self.visit(node.target.elts[0])
                    t2 = self.visit(node.target.elts[1])
                    self.output.append(f"{self._indent()}{t1} := {var_v1}")
                    self.output.append(f"{self._indent()}{t2} := {var_v2}")
                else:
                    target = self.visit(node.target)
                    self.output.append(f"{self._indent()}{target} := [{var_v1}, {var_v2}]")
                for stmt in node.body:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
                return

        target = self.visit(node.target)
        iter_expr = self.visit(node.iter)

        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name):
             if node.iter.func.id == "range":
                 range_args = node.iter.args
                 if len(range_args) == 3:
                     start = self.visit(range_args[0])
                     stop = self.visit(range_args[1])
                     step = self.visit(range_args[2])
                     is_negative_step = False
                     if isinstance(range_args[2], ast.UnaryOp) and isinstance(range_args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(range_args[2], ast.Constant) and isinstance(range_args[2].value, (int, float)) and range_args[2].value < 0:
                         is_negative_step = True
                     op = ">" if is_negative_step else "<"
                     self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
                     self._indent_level += 1
                     for stmt in node.body:
                         self.visit(stmt)
                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")
                     return
                 start = "0"
                 stop = "0"
                 if len(range_args) == 1:
                      stop = self.visit(range_args[0])
                 elif len(range_args) == 2:
                      start = self.visit(range_args[0])
                      stop = self.visit(range_args[1])
                 iter_expr = f"{start}..{stop}"
             elif node.iter.func.id == "enumerate":
                 if node.iter.args:
                     iter_expr = self.visit(node.iter.args[0])
                     if isinstance(node.target, ast.Tuple):
                         if target.startswith("[") and target.endswith("]"):
                             target = target[1:-1]
                     else:
                         self.output.append(f"{self._indent()}// TODO: handle enumerate with single target variable")

        self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Try(self, node: ast.Try) -> None:
        self.output.append(f"{self._indent()}// try {{")
        for stmt in node.body:
            self.visit(stmt)
        self.output.append(f"{self._indent()}// }} except {{")
        for handler in node.handlers:
            self.output.append(f"{self._indent()}// Handler: {handler.type}")
            self.output.append(f"{self._indent()}// ... exception handling logic ...")
        if node.finalbody:
             self.output.append(f"{self._indent()}// }} finally {{")
             self.output.append(f"{self._indent()}defer {{")
             self._indent_level += 1
             for stmt in node.finalbody:
                 self.visit(stmt)
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")

    def visit_With(self, node: ast.With) -> None:
        for item in node.items:
            # Special handling for contextlib.nullcontext and contextlib.suppress
            # Check if context_expr is a call to these functions
            is_nullcontext = False
            is_suppress = False
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
                    else:
                         # Heuristic for unimported or simple usage
                         if func.id == "nullcontext": is_nullcontext = True
                         if func.id == "suppress": is_suppress = True

                elif isinstance(func, ast.Attribute):
                    # contextlib.nullcontext
                    if isinstance(func.value, ast.Name):
                        module_alias = func.value.id
                        attr_name = func.attr

                        resolved_module = self.imported_modules.get(module_alias, module_alias)
                        if resolved_module == "contextlib":
                            if attr_name == "nullcontext": is_nullcontext = True
                            if attr_name == "suppress": is_suppress = True

            context_expr = self.visit(item.context_expr)

            if is_suppress:
                # suppress() maps to a comment via mapper, so context_expr is "/* ... */"
                # We just emit it as a statement (comment) and don't create a variable or defer
                self.output.append(f"{self._indent()}{context_expr}")
                continue

            if is_nullcontext:
                # nullcontext(x) maps to x.
                # We assign it to var if present, but do NOT defer close()
                if item.optional_vars:
                    var = self.visit(item.optional_vars)
                    self.output.append(f"{self._indent()}{var} := {context_expr}")
                else:
                    self.output.append(f"{self._indent()}_ = {context_expr}")
                continue

            if item.optional_vars:
                var = self.visit(item.optional_vars)
                self.output.append(f"{self._indent()}{var} := {context_expr}")
                self.output.append(f"{self._indent()}defer {{ {var}.close() }}")
            else:
                self.output.append(f"{self._indent()}_ := {context_expr}")
        for stmt in node.body:
            self.visit(stmt)

    def visit_Break(self, node: ast.Break) -> None:
        self.output.append(f"{self._indent()}break")

    def visit_Continue(self, node: ast.Continue) -> None:
        self.output.append(f"{self._indent()}continue")

    def visit_Match(self, node: "ast.Match") -> None:
        subject = self.visit(node.subject)
        self.output.append(f"{self._indent()}match {subject} {{")
        self._indent_level += 1
        for case in node.cases:
            self._visit_match_case(case)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def _visit_match_case(self, node: "ast.match_case") -> None:
        pattern_str = self._translate_pattern(node.pattern)
        if node.guard:
            self.output.append(f"{self._indent()}// Guard condition '{self.visit(node.guard)}' ignored in match case")
        self.output.append(f"{self._indent()}{pattern_str} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def _translate_pattern(self, pattern: ast.AST) -> str:
        if isinstance(pattern, ast.MatchValue):
            return str(self.visit(pattern.value))
        elif isinstance(pattern, ast.MatchSingleton):
            return str(pattern.value).lower()
        elif isinstance(pattern, ast.MatchOr):
            parts = [self._translate_pattern(p) for p in pattern.patterns]
            return ", ".join(parts)
        elif isinstance(pattern, ast.MatchAs):
             if pattern.name is None:
                 return "else"
             else:
                 return f"else /* bound to {pattern.name} */"
        return "else"
