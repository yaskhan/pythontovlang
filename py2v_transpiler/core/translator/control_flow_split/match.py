import ast
from typing import List, Tuple, Dict
from ..base import TranslatorBase

class MatchMixin(TranslatorBase):
    """Обработка match/case (Python 3.10+)"""
    
    def _unmangle_generic_name(self, name: str) -> str:
        """Restores generic syntax from mangled identifiers and maps Python types to V types."""
        from py2v_transpiler.models.v_types import map_python_type_to_v
        if "__py2v_gen_L__" not in name:
            return map_python_type_to_v(name)

        # Restore original syntax
        res = name.replace("__py2v_gen_L__", "[")
        res = res.replace("__py2v_gen_R__", "]")
        res = res.replace("__py2v_gen_C__", ", ")

        # Now map it properly using map_python_type_to_v
        return map_python_type_to_v(res)

    def visit_Match(self, node: "ast.Match") -> None:
        subject = self.visit(node.subject)
        self._zip_counter += 1
        match_id = self._zip_counter
        subject_var = f"_match_subject_{match_id}"
        found_var = f"_match_found_{match_id}"

        self.output.append(f"{self._indent()}// Match statement converted to separate if blocks")
        self.output.append(f"{self._indent()}{subject_var} := {subject}")
        # Create an 'any' alias for type checking
        subject_any = f"_match_subject_any_{match_id}"
        self.output.append(f"{self._indent()}{subject_any} := ({subject_var} as Any)")
        self.output.append(f"{self._indent()}mut {found_var} := false")

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

        for case in expanded_cases:
            cond, bindings = self._compile_pattern(case.pattern, subject_any)

            if cond == "true":
                self.output.append(f"{self._indent()}if !{found_var} {{")
            else:
                self.output.append(f"{self._indent()}if !{found_var} && ({cond}) {{")

            self._indent_level += 1
            for binding in bindings:
                self.output.append(f"{self._indent()}{binding}")

            if case.guard:
                guard_expr = self.visit(case.guard)
                self.output.append(f"{self._indent()}if ({guard_expr}) {{")
                self._indent_level += 1
                for stmt in case.body:
                    self.visit(stmt)
                self.output.append(f"{self._indent()}{found_var} = true")
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
            else:
                for stmt in case.body:
                    self.visit(stmt)
                self.output.append(f"{self._indent()}{found_var} = true")

            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

            if cond == "true" and not case.guard:
                break # Optimization: literal wildcard with no guard always matches

    def _compile_pattern(self, pattern: ast.AST, subject_expr: str) -> Tuple[str, List[str]]:
        bindings: List[str] = []

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

                         branches.append(f"{subject_expr} is {t} {{ (({subject_expr} as {t}){slice_expr} as Any) }}")
                     elif from_end:
                         # Index from end: len - offset
                         branches.append(f"{subject_expr} is {t} {{ (({subject_expr} as {t})[({subject_expr} as {t}).len - {idx}] as Any) }}")
                     else:
                         branches.append(f"{subject_expr} is {t} {{ (({subject_expr} as {t})[{idx}] as Any) }}")
                branches.append("else { (0 as Any) }") # Fallback
                return f"if {' else if '.join(branches[:-1])} {branches[-1]}"

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
                     branches.append(f"{subject_expr} is {t} {{ (({subject_expr} as {t})[{k_val}] as Any) }}")
                 branches.append("else { (0 as Any) }")
                 extract_expr = f"if {' else if '.join(branches[:-1])} {branches[-1]}"

                 sub_cond, sub_binds = self._compile_pattern(p, extract_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_binds)

             if rest:
                 self.used_builtins.add("py_dict_residual")
                 exclude_list = "[]string{" + ", ".join(self.visit(k) for k in keys) + "}"

                 branches = []
                 for t in map_types:
                     branches.append(f"{subject_expr} is {t} {{ (py_dict_residual(({subject_expr} as {t}), {exclude_list}) as Any) }}")
                 else_part = " else { (map[string]Any{} as Any) }"
                 extract_expr = f"if {' else if '.join(branches)}{else_part}"

                 bindings.append(f"{rest} := {extract_expr}")

             return cond, bindings

        elif isinstance(pattern, ast.MatchClass):
             cls_name = self.visit(pattern.cls)
             # Restore generic syntax if mangled and map Python types to V types
             cls_name = self._unmangle_generic_name(cls_name)

             cond = f"({subject_expr} is {cls_name})"

             # Handle positional patterns using __match_args__ or dataclass fields
             match_args = []
             if cls_name in self.dataclasses:
                 match_args = self.dataclasses[cls_name]

             for i, sub_pat in enumerate(pattern.patterns):
                 if i < len(match_args):
                     attr = match_args[i]
                 else:
                     # Fallback to positional index if unknown
                     # Python usually requires __match_args__ but we can try to be helpful
                     attr = f"_{i}"

                 cast_expr = f"({subject_expr} as {cls_name})"
                 val_expr = f"({cast_expr}.{attr} as Any)"
                 sub_cond, sub_bindings = self._compile_pattern(sub_pat, val_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_bindings)

             for attr, sub_pat in zip(pattern.kwd_attrs, pattern.kwd_patterns):
                 cast_expr = f"({subject_expr} as {cls_name})"
                 # Need to wrap in Any() for recursive generic check?
                 # _compile_pattern expects subject_expr to be Any if it does type checks.
                 # If we pass `${cast_expr}.attr`, it is typed.
                 # So we wrap it: `Any(...)`.
                 val_expr = f"({cast_expr}.{attr} as Any)"
                 sub_cond, sub_bindings = self._compile_pattern(sub_pat, val_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_bindings)

             return cond, bindings

        elif isinstance(pattern, ast.MatchOr):
            parts = []
            all_alternatives_bindings: List[List[str]] = []
            for p in pattern.patterns:
                alt_cond, alt_binds = self._compile_pattern(p, subject_expr)
                parts.append(f"({alt_cond})")
                all_alternatives_bindings.append(alt_binds)

            # Group bindings by variable name
            binding_map: Dict[str, List[Tuple[List[str], str]]] = {}
            for b_list in all_alternatives_bindings:
                for b_str in b_list:
                    name, expr = b_str.split(" := ", 1)
                    if name not in binding_map:
                        binding_map[name] = []
                    binding_map[name].append((b_list, expr))

            for name, alternatives in binding_map.items():
                if len(alternatives) == len(pattern.patterns):
                    # Variable is bound in all alternatives
                    first_expr = alternatives[0][1]
                    if all(alt[1] == first_expr for alt in alternatives):
                        # All alternatives bind to the exact same expression
                        bindings.append(f"{name} := {first_expr}")
                    else:
                        # Bindings differ (e.g., due to different narrowing)
                        # Generate: var := if cond1 { expr1 } else if cond2 { expr2 } ... else { exprN }
                        branches = []
                        for i, (b_list, expr) in enumerate(alternatives):
                            cond = parts[i]
                            if i == len(alternatives) - 1:
                                branches.append(f"else {{ {expr} }}")
                            else:
                                branches.append(f"{cond} {{ {expr} }}")

                        binding_expr = f"if {' else if '.join(branches[:-1])} {branches[-1]}"
                        bindings.append(f"{name} := {binding_expr}")

            return " || ".join(parts), bindings

        elif isinstance(pattern, ast.MatchAs):
             cond = "true"
             val_expr = subject_expr
             if pattern.pattern:
                 cond, sub_bindings = self._compile_pattern(pattern.pattern, subject_expr)
                 bindings.extend(sub_bindings)
                 # Narrowing: if the sub-pattern is a specific class, we can cast the variable
                 if isinstance(pattern.pattern, ast.MatchClass):
                     cls_name = self.visit(pattern.pattern.cls)
                     cls_name = self._unmangle_generic_name(cls_name)
                     val_expr = f"({subject_expr} as {cls_name})"
                 else:
                     # General type narrowing from mypy for the bound name
                     if pattern.name:
                        # Use location of the pattern to find the narrowed type of the variable
                        # In MatchAs, the variable is defined at this location.
                        loc_key = f"{pattern.name}@{getattr(pattern, 'lineno', 0)}:{getattr(pattern, 'col_offset', 0)}"
                        narrowed_type = self.type_inference.type_map.get(loc_key)

                        if not narrowed_type:
                            temp_node = ast.Name(id=pattern.name, ctx=ast.Store(), lineno=getattr(pattern, 'lineno', 0), col_offset=getattr(pattern, 'col_offset', 0))
                            narrowed_type = self._guess_type(temp_node)

                        if narrowed_type not in ("Any", "void", "int"):
                             val_expr = f"({subject_expr} as {narrowed_type})"

             if pattern.name:
                 # Check if the name itself should be narrowed based on mypy info
                 loc_key = f"{pattern.name}@{getattr(pattern, 'lineno', 0)}:{getattr(pattern, 'col_offset', 0)}"
                 narrowed_type = self.type_inference.type_map.get(loc_key)
                 if narrowed_type and narrowed_type not in ("Any", "void", "int"):
                      if " as " not in val_expr: # Avoid double cast
                           val_expr = f"({val_expr} as {narrowed_type})"
                 bindings.append(f"{pattern.name} := {val_expr}")
             return cond, bindings

        elif isinstance(pattern, ast.MatchStar):
             val_expr = subject_expr
             if pattern.name:
                 temp_node = ast.Name(id=pattern.name, ctx=ast.Store(), lineno=getattr(pattern, 'lineno', 0), col_offset=getattr(pattern, 'col_offset', 0))
                 narrowed_type = self._guess_type(temp_node)
                 if narrowed_type not in ("Any", "void"):
                      val_expr = f"({subject_expr} as {narrowed_type})"
                 bindings.append(f"{pattern.name} := {val_expr}")
             return "true", bindings

        return "false", bindings
