import ast
import re
from typing import List, Tuple, Dict
from ..base import TranslatorBase

# Pre-compiled regular expressions for performance
_GEN_L_RE = re.compile(r'__py2v_gen_L__', flags=re.IGNORECASE)
_GEN_R_RE = re.compile(r'__py2v_gen_R__', flags=re.IGNORECASE)
_GEN_C_RE = re.compile(r'__py2v_gen_C__', flags=re.IGNORECASE)
_GEN_L_SHORT_RE = re.compile(r'_py2v_gen_L_', flags=re.IGNORECASE)
_GEN_R_SHORT_RE = re.compile(r'_py2v_gen_R_', flags=re.IGNORECASE)
_GEN_C_SHORT_RE = re.compile(r'_py2v_gen_C_', flags=re.IGNORECASE)

class MatchMixin(TranslatorBase):
    """Handling match/case (Python 3.10+)"""
    
    def _unmangle_generic_name(self, name: str) -> str:
        """Restores generic syntax from mangled identifiers and maps Python types to V types."""
        from py2v_transpiler.models.v_types import map_python_type_to_v
        
        if "__py2v_gen" not in name.lower():
            return map_python_type_to_v(name)

        # Restore original syntax
        res = name
        res = _GEN_L_RE.sub('[', res)
        res = _GEN_R_RE.sub(']', res)
        res = _GEN_C_RE.sub(', ', res)
        
        # Handle some cases where underscores might have been changed
        res = _GEN_L_SHORT_RE.sub('[', res)
        res = _GEN_R_SHORT_RE.sub(']', res)
        res = _GEN_C_SHORT_RE.sub(', ', res)

        return map_python_type_to_v(res)

    def visit_Match(self, node: "ast.Match") -> None:
        subject = self.visit(node.subject)
        self._zip_counter += 1
        match_id = self._zip_counter
        subject_var = f"py_match_subject_{match_id}"
        found_var = f"py_match_found_{match_id}"

        self.output.append(f"{self._indent()}// Match statement converted to separate if blocks")
        self.output.append(f"{self._indent()}{subject_var} := {subject}")
        subject_any = f"py_match_subject_any_{match_id}"
        self.output.append(f"{self._indent()}{subject_any} := Any({subject_var})")
        self.output.append(f"{self._indent()}mut {found_var} := false")

        expanded_cases = []
        for case in node.cases:
            if isinstance(case.pattern, ast.MatchOr):
                for p in case.pattern.patterns:
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
                break

    def _compile_pattern(self, pattern: ast.AST, subject_expr: str) -> Tuple[str, List[str]]:
        bindings: List[str] = []

        if isinstance(pattern, ast.MatchValue):
            val = self.visit(pattern.value)
            return f"{subject_expr} == {val}", bindings

        elif isinstance(pattern, ast.MatchSingleton):
            val = str(pattern.value).lower()
            if pattern.value is None:
                 return f"{subject_expr} is none", bindings
            return f"{subject_expr} == {val}", bindings

        elif isinstance(pattern, ast.MatchSequence):
            array_types = ["[]int", "[]f64", "[]string", "[]bool", "[]Any"]
            patterns = pattern.patterns
            star_idx = -1
            for i, p in enumerate(patterns):
                if isinstance(p, ast.MatchStar):
                    star_idx = i
                    break

            checks = []
            or_parts = []

            def gen_extract(idx, is_rest=False, from_end=False):
                branches = []
                for t in array_types:
                     if is_rest:
                         num_trailing = len(patterns) - 1 - idx
                         end_expr = f"(({subject_expr} as {t}).len - {num_trailing})"
                         if num_trailing == 0:
                             slice_expr = f"[{idx}..]"
                         else:
                             slice_expr = f"[{idx}..{end_expr}]"
                         branches.append(f"{subject_expr} is {t} {{ Any(({subject_expr} as {t}){slice_expr}) }}")
                     elif from_end:
                         branches.append(f"{subject_expr} is {t} {{ Any(({subject_expr} as {t})[({subject_expr} as {t}).len - {idx}]) }}")
                     else:
                         branches.append(f"{subject_expr} is {t} {{ Any(({subject_expr} as {t})[{idx}]) }}")
                branches.append("else { Any(0) }")
                return f"if {' else if '.join(branches[:-1])} {branches[-1]}"

            num_patterns = len(patterns)
            for i, p in enumerate(patterns):
                if isinstance(p, ast.MatchStar):
                    if p.name:
                        binding_val = gen_extract(i, is_rest=True)
                        bindings.append(f"{p.name} := {binding_val}")
                    continue
                if star_idx != -1 and i > star_idx:
                    offset = num_patterns - i
                    sub_expr = gen_extract(offset, from_end=True)
                else:
                    sub_expr = gen_extract(i)
                sub_cond, sub_binds = self._compile_pattern(p, sub_expr)
                checks.append(f"({sub_cond})")
                bindings.extend(sub_binds)

            for t in array_types:
                cast = f"({subject_expr} as {t})"
                l_chk = f"{cast}.len == {len(patterns)}" if star_idx == -1 else f"{cast}.len >= {len(patterns) - 1}"
                or_parts.append(f"({subject_expr} is {t} && {l_chk})")

            type_len_condition = "(" + " || ".join(or_parts) + ")"
            full_condition = f"{type_len_condition} && {' && '.join(checks)}" if checks else type_len_condition
            return full_condition, bindings

        elif isinstance(pattern, ast.MatchMapping):
             map_types = ["map[string]int", "map[string]string", "map[string]Any"]
             keys = pattern.keys
             patterns = pattern.patterns
             rest = pattern.rest
             or_parts = []
             for t in map_types:
                 chk = f"({subject_expr} is {t})"
                 for k in keys:
                     k_val = self.visit(k)
                     chk += f" && ({k_val} in ({subject_expr} as {t}))"
                 or_parts.append(chk)
             cond = "(" + " || ".join(or_parts) + ")"
             for i, p in enumerate(patterns):
                 k_val = self.visit(keys[i])
                 branches = [f"{subject_expr} is {t} {{ Any(({subject_expr} as {t})[{k_val}]) }}" for t in map_types]
                 extract_expr = f"if {' else if '.join(branches)} else {{ Any(0) }}"
                 sub_cond, sub_binds = self._compile_pattern(p, extract_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_binds)
             if rest:
                 self.used_builtins.add("py_dict_residual")
                 exclude_list = "[]string{" + ", ".join(self.visit(k) for k in keys) + "}"
                 branches = [f"{subject_expr} is {t} {{ Any(py_dict_residual(({subject_expr} as {t}), {exclude_list})) }}" for t in map_types]
                 extract_expr = f"if {' else if '.join(branches)} else {{ Any(map[string]Any{{}}) }}"
                 bindings.append(f"{rest} := {extract_expr}")
             return cond, bindings

        elif isinstance(pattern, ast.MatchClass):
             cls_name_expr = self.visit(pattern.cls)
             cls_name = self._unmangle_generic_name(cls_name_expr)
             if not (cls_name[0].isupper() or "[" in cls_name):
                 cls_name = cls_name[0].upper() + cls_name[1:]
             cond = f"({subject_expr} is {cls_name})"
             match_args = self.dataclasses.get(cls_name) or self.dataclasses.get(cls_name_expr) or []
             for i, sub_pat in enumerate(pattern.patterns):
                 attr = match_args[i] if i < len(match_args) else f"py_{i}"
                 val_expr = f"Any(({subject_expr} as {cls_name}).{attr})"
                 sub_cond, sub_bindings = self._compile_pattern(sub_pat, val_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_bindings)
             for attr, sub_pat in zip(pattern.kwd_attrs, pattern.kwd_patterns):
                 val_expr = f"Any(({subject_expr} as {cls_name}).{attr})"
                 sub_cond, sub_bindings = self._compile_pattern(sub_pat, val_expr)
                 cond += f" && ({sub_cond})"
                 bindings.extend(sub_bindings)
             return cond, bindings

        elif isinstance(pattern, ast.MatchOr):
            parts = []
            all_alternatives_bindings = []
            for p in pattern.patterns:
                alt_cond, alt_binds = self._compile_pattern(p, subject_expr)
                parts.append(f"({alt_cond})")
                all_alternatives_bindings.append(alt_binds)
            binding_map: Dict[str, List[Tuple[List[str], str]]] = {}
            for b_list in all_alternatives_bindings:
                for b_str in b_list:
                    name, expr = b_str.split(" := ", 1)
                    binding_map.setdefault(name, []).append((b_list, expr))
            for name, alternatives in binding_map.items():
                if len(alternatives) == len(pattern.patterns):
                    first_expr = alternatives[0][1]
                    if all(alt[1] == first_expr for alt in alternatives):
                        bindings.append(f"{name} := {first_expr}")
                    else:
                        branches = [f"{parts[i]} {{ {alt[1]} }}" for i, alt in enumerate(alternatives[:-1])]
                        binding_expr = f"if {' else if '.join(branches)} else {{ {alternatives[-1][1]} }}"
                        bindings.append(f"{name} := {binding_expr}")
            return " || ".join(parts), bindings

        elif isinstance(pattern, ast.MatchAs):
             cond, val_expr = "true", subject_expr
             if pattern.pattern:
                 cond, sub_bindings = self._compile_pattern(pattern.pattern, subject_expr)
                 bindings.extend(sub_bindings)
                 if isinstance(pattern.pattern, ast.MatchClass):
                     cn_expr = self.visit(pattern.pattern.cls)
                     cn = self._unmangle_generic_name(cn_expr)
                     if not (cn[0].isupper() or "[" in cn): cn = cn[0].upper() + cn[1:]
                     val_expr = f"({subject_expr} as {cn})"
                 elif pattern.name:
                     loc_key = f"{pattern.name}@{getattr(pattern, 'lineno', 0)}:{getattr(pattern, 'col_offset', 0)}"
                     narrowed = self.type_inference.type_map.get(loc_key)
                     if not narrowed: narrowed = self._guess_type(ast.Name(id=pattern.name, ctx=ast.Store(), lineno=getattr(pattern, 'lineno', 0), col_offset=getattr(pattern, 'col_offset', 0)))
                     if narrowed not in ("Any", "void", "int"): val_expr = f"({subject_expr} as {narrowed})"
             if pattern.name:
                 loc_key = f"{pattern.name}@{getattr(pattern, 'lineno', 0)}:{getattr(pattern, 'col_offset', 0)}"
                 narrowed = self.type_inference.type_map.get(loc_key)
                 if narrowed and narrowed not in ("Any", "void", "int") and " as " not in val_expr:
                     val_expr = f"({val_expr} as {narrowed})"
                 bindings.append(f"{pattern.name} := {val_expr}")
             return cond, bindings

        elif isinstance(pattern, ast.MatchStar):
             val_expr = subject_expr
             if pattern.name:
                 narrowed = self._guess_type(ast.Name(id=pattern.name, ctx=ast.Store(), lineno=getattr(pattern, 'lineno', 0), col_offset=getattr(pattern, 'col_offset', 0)))
                 if narrowed not in ("Any", "void"): val_expr = f"({subject_expr} as {narrowed})"
                 bindings.append(f"{pattern.name} := {val_expr}")
             return "true", bindings

        return "false", bindings
