import ast
from .base import TranslatorBase
from typing import Dict, Any

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
        loop_ctx: Dict[str, Any] = {}
        flag_name = ""
        if node.orelse:
            flag_name = f"_loop_completed_{self.unique_id_counter}"
            self.unique_id_counter += 1
            self.output.append(f"{self._indent()}mut {flag_name} := true")
            loop_ctx['flag'] = flag_name
        loop_ctx['vexc_depth'] = self.vexc_depth

        self.loop_stack.append(loop_ctx)

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

        self.loop_stack.pop()

        if node.orelse:
            self.output.append(f"{self._indent()}if {flag_name} {{")
            self._indent_level += 1
            for stmt in node.orelse:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

    def visit_AsyncFor(self, node: ast.AsyncFor) -> None:
        # Treat async for similar to for loop over channel
        # Assuming node.iter returns a channel (async generator call)
        target = self.visit(node.target)
        iter_expr = self.visit(node.iter)

        # Push loop context to stack for break handling
        self.loop_stack.append({'vexc_depth': self.vexc_depth})

        self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

        self.loop_stack.pop()

        if node.orelse:
            self.output.append(f"{self._indent()}// else clause in async for not supported yet")

    def visit_For(self, node: ast.For) -> None:
        loop_ctx: Dict[str, Any] = {}
        flag_name = ""
        if node.orelse:
            flag_name = f"_loop_completed_{self.unique_id_counter}"
            self.unique_id_counter += 1
            self.output.append(f"{self._indent()}mut {flag_name} := true")
            loop_ctx['flag'] = flag_name
        loop_ctx['vexc_depth'] = self.vexc_depth

        self.loop_stack.append(loop_ctx)

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

                self.loop_stack.pop()
                if node.orelse:
                     self.output.append(f"{self._indent()}if {flag_name} {{")
                     self._indent_level += 1
                     for stmt in node.orelse:
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

                     self.loop_stack.pop()
                     if node.orelse:
                         self.output.append(f"{self._indent()}if {flag_name} {{")
                         self._indent_level += 1
                         for stmt in node.orelse:
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

        self.loop_stack.pop()
        if node.orelse:
            self.output.append(f"{self._indent()}if {flag_name} {{")
            self._indent_level += 1
            for stmt in node.orelse:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

    def visit_Raise(self, node: ast.Raise) -> None:
        self.emitter.add_import('div72.vexc')
        if node.exc:
            if isinstance(node.exc, ast.Call):
                 exc_name = self.visit(node.exc.func)
                 msg = ""
                 if node.exc.args:
                      msg = self.visit(node.exc.args[0])
                      # Remove quotes if it's a string literal visit
                      if msg.startswith("'") and msg.endswith("'"):
                           msg = msg[1:-1]
                      elif msg.startswith('"') and msg.endswith('"'):
                           msg = msg[1:-1]
                 self.output.append(f"{self._indent()}vexc.raise('{exc_name}', '{msg}')")
            elif isinstance(node.exc, ast.Name):
                 exc_name = self.visit(node.exc)
                 self.output.append(f"{self._indent()}vexc.raise('{exc_name}', '')")
            else:
                 val = self.visit(node.exc)
                 self.output.append(f"{self._indent()}vexc.raise('Exception', '${{{val}}}')")
        else:
            # Reraise
            self.output.append(f"{self._indent()}if vexc.get_curr_exc().name != '' {{")
            self.output.append(f"{self._indent()}    vexc.raise(vexc.get_curr_exc().name, vexc.get_curr_exc().msg)")
            self.output.append(f"{self._indent()}}} else {{")
            self.output.append(f"{self._indent()}    panic('reraise not supported outside except block')")
            self.output.append(f"{self._indent()}}}")

    def visit_Try(self, node: ast.Try) -> None:
        self.emitter.add_import('div72.vexc')

        # Need to support finally using defer
        if node.finalbody:
            self.finally_stack.append(node)
            # Check if finally block contains continue
            has_continue = False
            for stmt in node.finalbody:
                for sub in ast.walk(stmt):
                    if isinstance(sub, ast.Continue):
                        has_continue = True
                        break
                if has_continue: break

            if has_continue:
                self.output.append(f"{self._indent()}// Warning: 'continue' in 'finally' detected. 'defer' cannot be used.")
            else:
                self.output.append(f"{self._indent()}{{")
                self.output.append(f"{self._indent()}    defer {{")
                self._indent_level += 2
                for stmt in node.finalbody:
                    self.visit(stmt)
                self._indent_level -= 2
                self.output.append(f"{self._indent()}    }}")

        self.vexc_depth += 1
        self.output.append(f"{self._indent()}if C.try() {{")
        self._indent_level += 1

        for stmt in node.body:
            self.visit(stmt)

        if node.orelse:
            for stmt in node.orelse:
                self.visit(stmt)

        self.output.append(f"{self._indent()}vexc.end_try()")
        self._indent_level -= 1
        self.vexc_depth -= 1
        self.output.append(f"{self._indent()}}} else {{")
        self._indent_level += 1

        if node.handlers:
             exc_var = f"_exc_{self.unique_id_counter}"
             self.unique_id_counter += 1
             self.output.append(f"{self._indent()}{exc_var} := vexc.get_curr_exc()")

             is_first = True
             has_default = False

             for handler in node.handlers:
                 type_str = ""
                 if handler.type:
                     if isinstance(handler.type, ast.Tuple):
                         types = [str(self.visit(t)) for t in handler.type.elts]
                         type_str = " || ".join([f"{exc_var}.name == '{t}'" for t in types])
                     else:
                         type_str = f"{exc_var}.name == '{str(self.visit(handler.type))}'"
                 else:
                     has_default = True

                 if has_default:
                      prefix = "else"
                 else:
                      prefix = "if" if is_first else "else if"

                 if has_default:
                      self.output.append(f"{self._indent()}{prefix} {{")
                 else:
                      self.output.append(f"{self._indent()}{prefix} {type_str} {{")

                 self._indent_level += 1
                 if handler.name:
                      mapped_type = self.type_inference.type_map.get(handler.name)
                      if mapped_type and mapped_type not in ("void", "Any"):
                          self.output.append(f"{self._indent()}{handler.name} := {exc_var} as {mapped_type}")
                      else:
                          # Fallback to the AST node's type if mypy didn't track it
                          fallback_type = None
                          if handler.type:
                              if isinstance(handler.type, ast.Name):
                                  fallback_type = handler.type.id
                              elif isinstance(handler.type, ast.Attribute):
                                  fallback_type = handler.type.attr

                          if fallback_type and fallback_type not in ("Exception", "BaseException", "ExceptionGroup"):
                              self.output.append(f"{self._indent()}{handler.name} := {exc_var} as {fallback_type}")
                          else:
                              self.output.append(f"{self._indent()}{handler.name} := {exc_var}")

                 for stmt in handler.body:
                      self.visit(stmt)

                 self._indent_level -= 1
                 self.output.append(f"{self._indent()}}}")

                 is_first = False
                 if has_default: break

             if not has_default:
                  self.output.append(f"{self._indent()}else {{")
                  self.output.append(f"{self._indent()}    vexc.raise({exc_var}.name, {exc_var}.msg)")
                  self.output.append(f"{self._indent()}}}")
        else:
             # Just try/finally
             self.output.append(f"{self._indent()}_exc := vexc.get_curr_exc()")
             self.output.append(f"{self._indent()}vexc.raise(_exc.name, _exc.msg)")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

        if node.finalbody:
            self.finally_stack.pop()
            if not has_continue:
                 self.output.append(f"{self._indent()}}}")
            else:
                 # Inlining finally block
                 for stmt in node.finalbody:
                     self.in_finally = True
                     self.visit(stmt)
                     self.in_finally = False

    def visit_AsyncWith(self, node: ast.AsyncWith) -> None:
        # Similar logic to visit_With, assuming mapped V types support .close()
        for item in node.items:
            context_expr = self.visit(item.context_expr)

            if item.optional_vars:
                var = self.visit(item.optional_vars)
                self.output.append(f"{self._indent()}{var} := {context_expr}")
                self.output.append(f"{self._indent()}defer {{ {var}.close() }}")
            else:
                tmp_var = f"_ctx_mgr_{self._zip_counter}"
                self._zip_counter += 1
                self.output.append(f"{self._indent()}{tmp_var} := {context_expr}")
                self.output.append(f"{self._indent()}defer {{ {tmp_var}.close() }}")

        for stmt in node.body:
            self.visit(stmt)

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
                # If no variable is assigned, we still need to close it.
                # But we don't have a variable name. We should create a temp one.
                tmp_var = f"_ctx_mgr_{self._zip_counter}"
                self._zip_counter += 1
                self.output.append(f"{self._indent()}{tmp_var} := {context_expr}")
                self.output.append(f"{self._indent()}defer {{ {tmp_var}.close() }}")
        for stmt in node.body:
            self.visit(stmt)

    def visit_Break(self, node: ast.Break) -> None:
        if self.loop_stack:
            current_loop = self.loop_stack[-1]
            if 'flag' in current_loop:
                flag = current_loop['flag']
                self.output.append(f"{self._indent()}{flag} = false")

            target_depth = current_loop.get('vexc_depth', 0)
            diff = self.vexc_depth - target_depth
            for _ in range(diff):
                 self.output.append(f"{self._indent()}vexc.end_try()")
        else:
            for _ in range(self.vexc_depth):
                 self.output.append(f"{self._indent()}vexc.end_try()")

        self.output.append(f"{self._indent()}break")

    def visit_Continue(self, node: ast.Continue) -> None:
        # Check if we are inside a finally block that needs to be inlined
        if self.finally_stack:
            # Inline all active finally blocks from stack top down to ... ?
            # 'continue' exits the loop. So it exits all surrounding try/finally blocks inside the loop.
            # We need to inline ALL finally blocks that are inside the loop being continued.
            # But we don't track which loop we are in relative to finally stack easily here.
            # Assuming 'finally_stack' contains finally blocks for try-statements that we are currently inside.
            # If we 'continue', we exit all of them.
            # So we should emit all of them in reverse order (inner to outer).

            # Wait, 'finally_stack' contains `Try` nodes.
            # We need to emit their `finalbody`.
            # But we need to be careful not to emit finally blocks that are OUTSIDE the loop.
            # But `visit_For` / `visit_While` don't manage `finally_stack`.
            # If we are in a loop, `finally_stack` only contains `try` blocks entered *inside* that loop
            # (assuming we clear/save stack on loop entry? No, we don't).
            # If `try` is outside loop, `continue` inside loop doesn't trigger its finally (because continue just jumps to next iteration, staying inside outer try).
            # So we only care about `try` blocks that are *inside* the current loop scope.

            # We need to know which finally blocks are "active" for this continue.
            # Generally, any `try` entered since the innermost loop started.
            # We can track loop depth?
            # Or simplified: Inline *all* finally blocks currently in stack.
            # Because if we are in a loop, and there is a `try` in stack, it must be inside the loop (or the loop is inside the try).
            # If loop is inside try (`try { while { continue } }`), `continue` does NOT exit `try`.
            # So we must NOT inline `finally` of outer `try`.

            # Implementation Detail:
            # We need to mark `finally_stack` entries with loop depth or scope ID.
            # Or `visit_For`/`visit_While` can mark the stack size on entry.
            # Only inline finally blocks pushed *after* the current loop started.

            # Let's add `loop_depth` to `TranslatorBase`.
            # But `loop_depth` isn't tracked yet.
            # For this task, I will implement a simplified version:
            # Emit a warning if finally stack is not empty, and attempt to inline all (risky) or just warn.
            # "Support for 'continue' in 'finally'" usually refers to `continue` statements appearing *inside* the `finally` block itself.
            # "Support for 'continue' in 'finally' block (Python 3.8+)"
            # This feature allows `continue` to be used *inside* the `finally` clause.
            # Previous Python versions forbade it.
            # If `continue` is *inside* `finally`, it swallows the exception (if any) and continues the loop.
            # My logic above was about `continue` inside `try` triggering `finally`.
            # The task is about `continue` appearing IN `finally`.

            # If `continue` is in `finally`:
            # It executes when `finally` executes.
            # If `finally` executes due to normal flow, `continue` runs.
            # If `finally` executes due to exception, `continue` swallows exception and continues loop.
            # V `defer` does NOT support `continue`.
            # So if we are visiting `finally` block (which is in `defer` usually), we find `continue`.
            # We need to know if we are currently visiting a `finally` block.

            # Re-read plan step: "In visit_Continue, check if finally_stack is non-empty."
            # Actually, `finally_stack` as implemented tracks `try` blocks we are *inside*.
            # But we are visiting the `finalbody` of a `try`.
            # We are *inside* the `finally` block logic.
            # Does `finally_stack` include the `try` whose `finally` we are visiting?
            # My `visit_Try` pops before visiting handlers/finalbody?
            # `visit_Try` logic above:
            # push
            # visit body
            # pop
            # visit handlers
            # visit finalbody (inside defer)

            # So if we are in `finalbody`, `finally_stack` does NOT contain the current `try`.
            # So `finally_stack` is not useful for detecting if we are *in* a finally block of the current try.
            # We need a flag `in_finally`.
            pass

        if getattr(self, 'in_finally', False):
             # We are inside a finally block.
             # V `defer` cannot contain `continue`.
             # We must rely on the fact that we emitted `defer`?
             # If we emit `continue` inside `defer`, V compiler error.
             # We should emit `// Warning: continue inside finally (defer) is not supported in V`.
             # Or we try to emit the `continue` and let user handle it?
             # The task is "Support".
             # If we can't use `defer`, we must inline `finally` logic at all exit points of `try` and `except`.
             # This requires rewriting the whole `try/finally` logic which is complex (AST transformation).
             # Given the scope, detecting and warning or emitting unsafe code is plausible.
             # But wait, I can modify `visit_Try` to check if `finalbody` contains `continue`.
             # If so, do NOT use `defer`. Instead, emit `finalbody` manually.
             pass

        if self.loop_stack:
            current_loop = self.loop_stack[-1]
            target_depth = current_loop.get('vexc_depth', 0)
            diff = self.vexc_depth - target_depth
            for _ in range(diff):
                 self.output.append(f"{self._indent()}vexc.end_try()")
        else:
            for _ in range(self.vexc_depth):
                 self.output.append(f"{self._indent()}vexc.end_try()")

        self.output.append(f"{self._indent()}continue")

    def visit_Match(self, node: "ast.Match") -> None:
        subject = self.visit(node.subject)
        self._zip_counter += 1
        match_id = self._zip_counter
        subject_var = f"_match_subject_{match_id}"

        self.output.append(f"{self._indent()}// Match statement converted to if-else chain")
        self.output.append(f"{self._indent()}{subject_var} := {subject}")
        # Create an 'any' alias for type checking
        subject_any = f"_match_subject_any_{match_id}"
        self.output.append(f"{self._indent()}{subject_any} := Any({subject_var})")

        # Flatten MatchOr patterns to simplify code generation
        expanded_cases = []
        for case in node.cases:
            if isinstance(case.pattern, ast.MatchOr):
                for p in case.pattern.patterns:
                    # Create a new case for each alternative
                    # We reuse the same body and guard
                    expanded_cases.append(ast.match_case(pattern=p, guard=case.guard, body=case.body))
            else:
                expanded_cases.append(case)

        is_first = True
        for case in expanded_cases:
            cond, bindings = self._compile_pattern(case.pattern, subject_any)

            if case.guard:
                guard_expr = self.visit(case.guard)
                cond = f"({cond}) && ({guard_expr})"

            prefix = "if" if is_first else "else if"
            if cond == "true":
                # Wildcard or fallback
                prefix = "else"
                self.output.append(f"{self._indent()}{prefix} {{")
            else:
                self.output.append(f"{self._indent()}{prefix} {cond} {{")

            self._indent_level += 1
            for binding in bindings:
                self.output.append(f"{self._indent()}{binding}")
            for stmt in case.body:
                self.visit(stmt)
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

            if cond == "true":
                break # Stop processing further cases as this one matches everything
            is_first = False

    def _compile_pattern(self, pattern: ast.AST, subject_expr: str) -> "tuple[str, list[str]]":
        bindings: list[str] = []

        if isinstance(pattern, ast.MatchValue):
            val = self.visit(pattern.value)
            # Use strict equality if types match, or just equality
            return f"{subject_expr} == {val}", bindings

        elif isinstance(pattern, ast.MatchSingleton):
            val = str(pattern.value).lower()
            if pattern.value is None:
                 return f"{subject_expr} is none", bindings # V uses 'none' not 'None'
            return f"{subject_expr} == {val}", bindings

        elif isinstance(pattern, ast.MatchSequence):
            # Support basic array types
            array_types = ["[]int", "[]f64", "[]string", "[]bool", "[]Any"]

            # Identify parts
            patterns = pattern.patterns
            star_idx = -1
            for i, p in enumerate(patterns):
                if isinstance(p, ast.MatchStar):
                    star_idx = i
                    break

            checks = []
            or_parts = []

            # Helper to generate extraction code
            def gen_extract(idx, is_rest=False, from_end=False):
                # Returns expression to get element at idx handling types
                branches = []
                for t in array_types:
                     if is_rest:
                         # Rest slicing: [idx .. len-end]
                         num_trailing = len(patterns) - 1 - idx
                         end_expr = f"(({subject_expr} as {t}).len - {num_trailing})"
                         if num_trailing == 0:
                             slice_expr = f"[{idx}..]"
                         else:
                             slice_expr = f"[{idx}..{end_expr}]"

                         branches.append(f"{subject_expr} is {t} {{ Any(({subject_expr} as {t}){slice_expr}) }}")
                     elif from_end:
                         # Index from end: len - offset
                         branches.append(f"{subject_expr} is {t} {{ Any(({subject_expr} as {t})[({subject_expr} as {t}).len - {idx}]) }}")
                     else:
                         branches.append(f"{subject_expr} is {t} {{ Any(({subject_expr} as {t})[{idx}]) }}")
                branches.append("else { Any(0) }") # Fallback
                return f"if {' else if '.join(branches)}"

            # Generate condition
            num_patterns = len(patterns)

            for i, p in enumerate(patterns):
                if isinstance(p, ast.MatchStar):
                    if p.name:
                        binding_val = gen_extract(i, is_rest=True)
                        bindings.append(f"{p.name} := {binding_val}")
                    continue

                # Determine index extraction method
                if star_idx != -1 and i > star_idx:
                    # After star: Index from end
                    offset = num_patterns - i
                    sub_expr = gen_extract(offset, from_end=True)
                else:
                    # Before star or no star: Direct index
                    sub_expr = gen_extract(i)

                sub_cond, sub_binds = self._compile_pattern(p, sub_expr)
                checks.append(f"({sub_cond})")
                bindings.extend(sub_binds)

            # Combine length checks and type checks
            for t in array_types:
                cast = f"({subject_expr} as {t})"
                if star_idx == -1:
                    l_chk = f"{cast}.len == {len(patterns)}"
                else:
                    l_chk = f"{cast}.len >= {len(patterns) - 1}"
                or_parts.append(f"({subject_expr} is {t} && {l_chk})")

            type_len_condition = "(" + " || ".join(or_parts) + ")"

            if checks:
                full_condition = f"{type_len_condition} && {' && '.join(checks)}"
            else:
                full_condition = type_len_condition

            return full_condition, bindings

        elif isinstance(pattern, ast.MatchMapping):
             # Simplified: Check if map[string]Any or similar
             # V maps are specific.
             # We assume map[string]int, map[string]string, map[string]Any.
             map_types = ["map[string]int", "map[string]string", "map[string]Any"]

             keys = pattern.keys
             patterns = pattern.patterns
             rest = pattern.rest

             or_parts = []
             for t in map_types:
                 # Check type
                 chk = f"({subject_expr} is {t})"
                 # Check keys exist
                 for k in keys:
                     k_val = self.visit(k) # literal string usually
                     chk += f" && ({k_val} in ({subject_expr} as {t}))"
                 or_parts.append(chk)

             cond = "(" + " || ".join(or_parts) + ")"

             # Sub patterns
             for i, p in enumerate(patterns):
                 k_val = self.visit(keys[i])

                 # Extract
                 branches = []
                 for t in map_types:
                     branches.append(f"{subject_expr} is {t} {{ Any(({subject_expr} as {t})[{k_val}]) }}")
                 branches.append("else { Any(0) }")
                 extract_expr = f"if {' else if '.join(branches)}"

                 sub_cond, sub_binds = self._compile_pattern(p, extract_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_binds)

             if rest:
                 # Capture rest? Complex. Ignore for now.
                 pass

             return cond, bindings

        elif isinstance(pattern, ast.MatchClass):
             cls_name = self.visit(pattern.cls)
             cond = f"({subject_expr} is {cls_name})"

             for attr, sub_pat in zip(pattern.kwd_attrs, pattern.kwd_patterns):
                 cast_expr = f"({subject_expr} as {cls_name})"
                 # Need to wrap in Any() for recursive generic check?
                 # _compile_pattern expects subject_expr to be Any if it does type checks.
                 # If we pass `${cast_expr}.attr`, it is typed.
                 # So we wrap it: `Any(...)`.
                 val_expr = f"Any({cast_expr}.{attr})"
                 sub_cond, sub_bindings = self._compile_pattern(sub_pat, val_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_bindings)

             return cond, bindings

        elif isinstance(pattern, ast.MatchOr):
            parts = []
            # bindings must be identical
            for p in pattern.patterns:
                c, b = self._compile_pattern(p, subject_expr)
                parts.append(f"({c})")
                if not bindings: bindings.extend(b)
            return " || ".join(parts), bindings

        elif isinstance(pattern, ast.MatchAs):
             if pattern.name:
                 bindings.append(f"{pattern.name} := {subject_expr}")
             return "true", bindings

        elif isinstance(pattern, ast.MatchStar):
             if pattern.name:
                 bindings.append(f"{pattern.name} := {subject_expr}")
             return "true", bindings

        return "false", bindings
