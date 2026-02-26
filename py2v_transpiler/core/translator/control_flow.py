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

    def visit_AsyncFor(self, node: ast.AsyncFor) -> None:
         # Reuse the generator detection logic from visit_For
         # In Python, async for works on async iterables.
         # For transpilation purposes, we assume async iterators are mapped to channels if they are generators.

         iter_node = node.iter
         if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name):
            if self.coroutine_handler.is_generator(iter_node.func.id):
                 # Generate setup
                 ch_name = self.coroutine_handler.get_temp_channel_name()
                 yield_type = self.coroutine_handler.get_generator_type(iter_node.func.id)
                 self.output.append(f"{self._indent()}{ch_name} := chan {yield_type}{{cap: 0}}")

                 # Call spawn
                 # Construct args
                 func_name = iter_node.func.id
                 spawn_args = [ch_name] + [str(self.visit(a)) for a in iter_node.args]
                 for kw in iter_node.keywords:
                     val = self.visit(kw.value)
                     spawn_args.append(f"{kw.arg}: {val}")

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

         # Fallback for generic async iterable
         target = self.visit(node.target)
         iter_expr = self.visit(node.iter)
         self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
         self._indent_level += 1
         for stmt in node.body:
            self.visit(stmt)
         self._indent_level -= 1
         self.output.append(f"{self._indent()}}}")

    def visit_AsyncWith(self, node: ast.AsyncWith) -> None:
        # Map to standard visit_With, assuming context managers are compatible (defer)
        # Note: We need to cast node to ast.With-like structure or just duplicate logic.
        # Duplicating logic is safer.
        self._zip_counter += 1
        counter = self._zip_counter

        for i, item in enumerate(node.items):
            context_expr = self.visit(item.context_expr)

            # We must capture the context manager in a variable to close it
            temp_var = f"_async_with_{counter}_{i}"

            if item.optional_vars:
                # Check if destructuring (Tuple or List)
                if isinstance(item.optional_vars, (ast.Tuple, ast.List)):
                     # Destructuring case: `async with CM() as (a, b):`
                     # We use a temp var for the context manager to ensure we can close it.
                     # Then we destructure the temp var into user variables.
                     self.output.append(f"{self._indent()}{temp_var} := {context_expr}")
                     self.output.append(f"{self._indent()}defer {{ {temp_var}.close() }}")

                     # Destructure temp_var into user vars using VariablesMixin logic
                     # We assume self._visit_destructuring is available via VariablesMixin
                     if hasattr(self, '_visit_destructuring'):
                         self._visit_destructuring(item.optional_vars, temp_var)
                     else:
                         self.output.append(f"{self._indent()}// Error: Destructuring support missing for async with")
                else:
                     # Simple case: `async with CM() as var:`
                     var = self.visit(item.optional_vars)
                     self.output.append(f"{self._indent()}{var} := {context_expr}")
                     self.output.append(f"{self._indent()}defer {{ {var}.close() }}")
            else:
                # No variable bound: `async with CM():`
                # We MUST still close it.
                self.output.append(f"{self._indent()}{temp_var} := {context_expr}")
                self.output.append(f"{self._indent()}defer {{ {temp_var}.close() }}")

        for stmt in node.body:
            self.visit(stmt)

    def visit_Try(self, node: ast.Try) -> None:
        self.output.append(f"{self._indent()}// try {{")
        for stmt in node.body:
            self.visit(stmt)
        self.output.append(f"{self._indent()}// }} except {{")
        for handler in node.handlers:
            type_str = ""
            if handler.type:
                if isinstance(handler.type, ast.Tuple):
                    types = [str(self.visit(t)) for t in handler.type.elts]
                    type_str = ", ".join(types)
                else:
                    type_str = str(self.visit(handler.type))
            else:
                type_str = "Exception"

            name_str = f" as {handler.name}" if handler.name else ""
            self.output.append(f"{self._indent()}// Handler: {type_str}{name_str}")
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
        self._zip_counter += 1
        match_id = self._zip_counter
        subject_var = f"_match_subject_{match_id}"

        self.output.append(f"{self._indent()}// Match statement converted to if-else chain")
        self.output.append(f"{self._indent()}{subject_var} := {subject}")
        # Create an 'any' alias for type checking
        subject_any = f"_match_subject_any_{match_id}"
        self.output.append(f"{self._indent()}{subject_any} := any({subject_var})")

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
            array_types = ["[]int", "[]f64", "[]string", "[]bool", "[]any"]

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

                         branches.append(f"{subject_expr} is {t} {{ any(({subject_expr} as {t}){slice_expr}) }}")
                     elif from_end:
                         # Index from end: len - offset
                         branches.append(f"{subject_expr} is {t} {{ any(({subject_expr} as {t})[({subject_expr} as {t}).len - {idx}]) }}")
                     else:
                         branches.append(f"{subject_expr} is {t} {{ any(({subject_expr} as {t})[{idx}]) }}")
                branches.append("else { any(0) }") # Fallback
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
             # Simplified: Check if map[string]any or similar
             # V maps are specific.
             # We assume map[string]int, map[string]string, map[string]any.
             map_types = ["map[string]int", "map[string]string", "map[string]any"]

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
                     branches.append(f"{subject_expr} is {t} {{ any(({subject_expr} as {t})[{k_val}]) }}")
                 branches.append("else { any(0) }")
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

             # Handle positional patterns (if class is known dataclass)
             if pattern.patterns:
                 # Check if we have field info
                 field_order = []
                 if hasattr(self, 'dataclasses') and cls_name in self.dataclasses:
                     field_order = self.dataclasses[cls_name]

                 for i, sub_pat in enumerate(pattern.patterns):
                     if i < len(field_order):
                         attr = field_order[i]
                         cast_expr = f"({subject_expr} as {cls_name})"
                         # Unwrap to access field directly
                         val_expr = f"{cast_expr}.{attr}"
                         sub_cond, sub_bindings = self._compile_pattern(sub_pat, val_expr)
                         cond += f" && ({sub_cond})"
                         bindings.extend(sub_bindings)
                     else:
                         # No field info or out of bounds - can't verify
                         # Just fail match? Or emit warning?
                         # Safe to just ignore or emit False?
                         # If user wrote valid python, there must be a field.
                         # If we don't know it, we can't generate V code.
                         cond += " && false /* Unknown positional field */"

             for attr, sub_pat in zip(pattern.kwd_attrs, pattern.kwd_patterns):
                 cast_expr = f"({subject_expr} as {cls_name})"
                 val_expr = f"{cast_expr}.{attr}"
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
