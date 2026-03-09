import ast
from ..base import TranslatorBase

class ConditionalsMixin(TranslatorBase):
    """Обработка условных операторов: if, elif, else"""

    def _is_name_main(self, node: ast.If) -> bool:
        """Checks for if __name__ == "__main__":"""
        if isinstance(node.test, ast.Compare):
            if (isinstance(node.test.left, ast.Name) and node.test.left.id == "__name__" and
                len(node.test.comparators) == 1 and isinstance(node.test.comparators[0], ast.Constant) and
                node.test.comparators[0].value == "__main__"):
                return True
        return False

    def _has_walrus(self, node: ast.AST) -> bool:
        """Checks if an expression contains a walrus operator."""
        for child in ast.walk(node):
            if isinstance(child, ast.NamedExpr):
                return True
        return False

    def visit_If(self, node: ast.If) -> None:
        self._visit_if(node, is_elif=False)

    def _collect_narrowing(self, node: ast.AST, positive: bool) -> dict[str, str]:
        """Manually identifies narrowing patterns in a test expression."""
        res = {}
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "isinstance":
             if positive and len(node.args) == 2 and isinstance(node.args[0], ast.Name):
                  var_name = node.args[0].id
                  try:
                      arg1 = node.args[1]
                      if isinstance(arg1, ast.Tuple):
                           parts = []
                           for elt in arg1.elts:
                                parts.append(self._map_type(ast.unparse(elt)))
                           v_type = self._register_sum_type(" | ".join(sorted(list(set(parts)))))
                      else:
                           v_type = self._map_type(ast.unparse(arg1))

                      if v_type not in ("Any", "void", "unknown"):
                          res[var_name] = v_type
                  except: pass
        elif isinstance(node, ast.Compare) and len(node.ops) == 1:
             op = node.ops[0]
             left = node.left
             right = node.comparators[0]
             if isinstance(left, ast.Name):
                  var_name = left.id
                  is_none = False
                  if isinstance(right, ast.Constant) and right.value is None: is_none = True
                  elif isinstance(right, ast.Name) and right.id in ("None", "none"): is_none = True

                  if is_none:
                       if (isinstance(op, (ast.IsNot, ast.NotEq)) and positive) or (isinstance(op, (ast.Is, ast.Eq)) and not positive):
                            # Narrow from ?T to T
                            orig_type = self.type_inference.type_map.get(var_name)
                            if not orig_type:
                                 orig_type = self._guess_type(left)

                            if orig_type and orig_type.startswith("?"):
                                 res[var_name] = orig_type[1:]
                       elif (isinstance(op, (ast.Is, ast.Eq)) and positive) or (isinstance(op, (ast.IsNot, ast.NotEq)) and not positive):
                            res[var_name] = "none"
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
             return self._collect_narrowing(node.operand, not positive)
        elif isinstance(node, ast.BoolOp) and isinstance(node.op, ast.And) and positive:
             for val in node.values:
                  res.update(self._collect_narrowing(val, True))
        elif isinstance(node, ast.BoolOp) and isinstance(node.op, ast.Or) and not positive:
             for val in node.values:
                  res.update(self._collect_narrowing(val, False))
        return res

    def _apply_flow_narrowing(self, body_nodes: list[ast.stmt], test_node: ast.AST | None = None, positive: bool = True) -> dict[str, str | None]:
        """Narrows variable types based on Mypy's location-based inference AND manual patterns."""
        if not body_nodes:
            return {}

        narrowed_vars: dict[str, str] = {}
        var_base_types: dict[str, str] = {}
        original_remaps: dict[str, str | None] = {}

        # 1. Manual Pattern Narrowing (high confidence)
        if test_node:
             manual_narrowing = self._collect_narrowing(test_node, positive)
             for v, t in manual_narrowing.items():
                  narrowed_vars[v] = t
                  # For manual narrowing, try to get base type
                  bt = self.type_inference.type_map.get(v)
                  if not bt: bt = self._guess_type(ast.Name(id=v, ctx=ast.Load()))
                  var_base_types[v] = bt

        # 2. Mypy location-based narrowing (supplementary)
        if hasattr(self.type_inference, "type_map"):
            first_node = body_nodes[0]
            line = getattr(first_node, "lineno", 0)
            col = getattr(first_node, "col_offset", 0)

            for var_name in list(self._local_vars_in_scope):
                if var_name in narrowed_vars: continue

                sanitized_name = self._sanitize_name(var_name)
                # Try specific location
                loc_key = f"{var_name}@{line}:{col}"
                narrowed_type = self.type_inference.type_map.get(loc_key)

                if not narrowed_type:
                    # Try line wildcard
                    loc_key = f"{var_name}@{line}:*"
                    narrowed_type = self.type_inference.type_map.get(loc_key)

                if not narrowed_type:
                    # Try sanitized name
                    loc_key = f"{sanitized_name}@{line}:{col}"
                    narrowed_type = self.type_inference.type_map.get(loc_key)
                    if not narrowed_type:
                         loc_key = f"{sanitized_name}@{line}:*"
                         narrowed_type = self.type_inference.type_map.get(loc_key)

                if not narrowed_type:
                    continue

                base_type = self.type_inference.type_map.get(var_name)
                if not base_type:
                    base_type = self.type_inference.type_map.get(sanitized_name)

                if not base_type or base_type == "Any":
                    continue

                if narrowed_type != base_type:
                    if base_type.startswith("?") and base_type[1:] == narrowed_type:
                        continue
                    if narrowed_type == "Any" or base_type == "Any":
                        continue
                    narrowed_vars[var_name] = narrowed_type
                    var_base_types[var_name] = base_type

        # Emit shadowed assignments for all narrowed variables
        for var_name, narrowed_type in narrowed_vars.items():
             if narrowed_type == "none":
                  # Variable is known to be None/none.
                  # We could potentially shadow it but V's 'none' isn't really a type you want to shadow with often
                  continue

             # If it is a SumType name from mypy, we need to map it
             if " | " in narrowed_type or "builtins." in narrowed_type:
                  narrowed_type = self._map_type(narrowed_type)

             sanitized_name = self._sanitize_name(var_name)
             # V doesn't allow shadowing of parameters or variables in the same scope.
             # However, V's `if x is Type` auto-narrows `x` within the block anyway.
             # To handle complex narrowing (like TypeGuard) without redeclaration,
             # we check if the variable is already in scope.
             if var_name in self._local_vars_in_scope:
                  # If already in scope, we rely on V's auto-narrowing for simple cases.
                  # Patterns where V can auto-narrow: T | None check, SumType is Type check.
                  # In these cases, we do NOT want to use a `narrowed_` prefix or create a new variable.
                  is_v_auto_narrowable = False
                  bt = var_base_types.get(var_name)
                  if bt and bt.startswith("?") and narrowed_type == bt[1:]:
                       is_v_auto_narrowable = True
                  elif bt and (bt.startswith("SumType_") or "|" in bt) and ("SumType_" not in narrowed_type and "|" not in narrowed_type):
                       is_v_auto_narrowable = True

                  if is_v_auto_narrowable:
                       # Rely on V auto-narrowing, no remap or declaration needed
                       continue

                  # If already in scope, we use a different name for the narrowed version
                  # to avoid redefinition while still allowing type-safe access.
                  # BUT only if narrowing to a specific non-Any type.
                  if narrowed_type not in ("Any", "void", "none"):
                      narrowed_name = f"narrowed_{sanitized_name}"
                      if narrowed_type in ("int", "f64", "string", "bool"):
                           self.output.append(f"{self._indent()}{narrowed_name} := {narrowed_type}({sanitized_name})")
                      else:
                           self.output.append(f"{self._indent()}{narrowed_name} := ({sanitized_name} as {narrowed_type})")
                      # Map original name to narrowed name within this block
                      original_remaps[var_name] = self.name_remap.get(var_name)
                      self.name_remap[var_name] = narrowed_name
             else:
                  # If not in scope (should not happen for parameters/locals, but maybe for globals),
                  # we can declare it.
                  if narrowed_type not in ("Any", "void", "none"):
                      if narrowed_type in ("int", "f64", "string", "bool"):
                           self.output.append(f"{self._indent()}{sanitized_name} := {narrowed_type}({sanitized_name})")
                      else:
                           self.output.append(f"{self._indent()}{sanitized_name} := ({sanitized_name} as {narrowed_type})")
                      self._local_vars_in_scope.add(var_name)

        return original_remaps

    def _visit_if(self, node: ast.If, is_elif: bool = False) -> None:
        if not is_elif:
            # Check for if __name__ == "__main__":
            if self._is_name_main(node):
                self.output.append(f"{self._indent()}// if __name__ == '__main__':")
                for stmt in node.body:
                    self.visit(stmt)
                return

            if_vars = self._collect_assigned_vars(node.body)
            else_vars = self._collect_assigned_vars(node.orelse) if node.orelse else set()

            # Pre-declare conditionally initialized variables
            for var in (if_vars | else_vars):
                if not self.in_main and var not in self._local_vars_in_scope:
                    v_type = self._guess_type(ast.Name(id=var, ctx=ast.Store()))
                    if v_type == "unknown":
                        v_type = "Any"
                    if not v_type.startswith("?"):
                        v_type = f"?{v_type}"

                    # They are always mut because they are assigned later
                    self.output.append(f"{self._indent()}mut {var} := {v_type}(none)")
                    self._local_vars_in_scope.add(var)

        # Check for TypeGuard / TypeIs narrowing
        narrow_if = None
        narrow_else = None
        remap_if = None
        remap_else = None

        if isinstance(node.test, ast.Call):
            call_node = node.test
            func_name_str = None
            if isinstance(call_node.func, ast.Name):
                func_name_str = call_node.func.id
            elif isinstance(call_node.func, ast.Attribute):
                func_name_str = call_node.func.attr

            loc_key = f"{getattr(call_node, 'lineno', 0)}:{getattr(call_node, 'col_offset', 0)}"
            call_sig = None
            if func_name_str and hasattr(self.type_inference, "call_signatures"):
                for k, v in self.type_inference.call_signatures.items():
                    if k.endswith(f".{func_name_str}@{loc_key}"):
                        call_sig = v
                        break
                if not call_sig:
                    for k, v in self.type_inference.call_signatures.items():
                        if k.endswith(f"@{loc_key}") and func_name_str in k:
                            call_sig = v
                            break
                if not call_sig:
                    for k, v in self.type_inference.call_signatures.items():
                        if k == loc_key:
                            call_sig = v
                            break

            if call_sig and "return" in call_sig:
                ret_typ = call_sig["return"]
                is_typeguard = "TypeGuard[" in ret_typ
                is_typeis = "TypeIs[" in ret_typ

                if (is_typeguard or is_typeis) and len(call_node.args) == 1:
                    arg_node = call_node.args[0]
                    if isinstance(arg_node, ast.Name):
                        arg_name = self._sanitize_name(arg_node.id)
                        import re
                        m = re.search(r'(?:TypeGuard|TypeIs)\[(.*?)\]', ret_typ)
                        if m:
                            inner_type = m.group(1)
                            from py2v_transpiler.models.v_types import map_python_type_to_v
                            v_narrowed_type = map_python_type_to_v(inner_type)
                            if v_narrowed_type == "builtins.str": v_narrowed_type = "string"
                            elif v_narrowed_type == "builtins.int": v_narrowed_type = "int"
                            elif v_narrowed_type == "builtins.float": v_narrowed_type = "f64"
                            elif v_narrowed_type == "builtins.bool": v_narrowed_type = "bool"

                            # Use a unique name for narrowing to avoid redefinition errors in V
                            narrowed_arg_name = f"narrowed_{arg_name}"
                            narrow_if = f"{narrowed_arg_name} := ({arg_name} as {v_narrowed_type})"
                            remap_if = (arg_name, narrowed_arg_name)

                            if is_typeis:
                                orig_type = self._guess_type(arg_node)
                                v_remaining_type = None

                                if orig_type.startswith("?"):
                                    if v_narrowed_type == orig_type[1:]:
                                        v_remaining_type = "none"
                                    elif v_narrowed_type == "none":
                                        v_remaining_type = orig_type[1:]
                                elif " | " in orig_type:
                                    parts = [p.strip() for p in orig_type.split("|")]
                                    if v_narrowed_type in parts:
                                        parts.remove(v_narrowed_type)
                                        v_remaining_type = " | ".join(parts)
                                    else:
                                        mapped_parts = []
                                        for p in parts:
                                            if p == "int" and v_narrowed_type == "int": continue
                                            if p == "string" and v_narrowed_type == "string": continue
                                            if p == "f64" and v_narrowed_type == "f64": continue
                                            if p == "bool" and v_narrowed_type == "bool": continue
                                            mapped_parts.append(p)
                                        if mapped_parts:
                                            v_remaining_type = " | ".join(mapped_parts)
                                        else:
                                            v_remaining_type = "Any"
                                else:
                                    v_remaining_type = "Any"

                                if v_remaining_type:
                                    narrow_else_name = f"narrowed_else_{arg_name}"
                                    if v_remaining_type == "none" and orig_type.startswith("?"):
                                        narrow_else = f"{narrow_else_name} := {orig_type}(none)"
                                    else:
                                        narrow_else = f"{narrow_else_name} := ({arg_name} as {v_remaining_type})"
                                    remap_else = (arg_name, narrow_else_name)

        # Check for walrus operator
        self._walrus_assignments = []
        test_expr = self._wrap_bool(node.test)

        if self._walrus_assignments:
             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")
             self._walrus_assignments = []

        if is_elif:
            last_line = self.output.pop()
            self.output.append(f"{last_line}if {test_expr} {{")
        else:
            self.output.append(f"{self._indent()}if {test_expr} {{")

        self._indent_level += 1

        body_remapped: dict[str, str | None] = {}
        if narrow_if:
             self.output.append(f"{self._indent()}{narrow_if}")
             if remap_if:
                  body_remapped[remap_if[0]] = self.name_remap.get(remap_if[0])
                  self.name_remap[remap_if[0]] = remap_if[1]
        else:
             body_remapped = self._apply_flow_narrowing(node.body, node.test, positive=True)

        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1

        # Restore remaps after body
        for var, original_val in body_remapped.items():
             if original_val is None:
                  if var in self.name_remap: del self.name_remap[var]
             else:
                  self.name_remap[var] = original_val

        if node.orelse:
            if (len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If) and
                not narrow_else and not self._is_name_main(node.orelse[0]) and
                not self._has_walrus(node.orelse[0].test)):
                # Optimized elif case: else if
                self.output.append(f"{self._indent()}}} else ")
                self._visit_if(node.orelse[0], is_elif=True)
            else:
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                else_remapped: dict[str, str | None] = {}
                if narrow_else:
                    self.output.append(f"{self._indent()}{narrow_else}")
                    if remap_else:
                         else_remapped[remap_else[0]] = self.name_remap.get(remap_else[0])
                         self.name_remap[remap_else[0]] = remap_else[1]
                else:
                    else_remapped = self._apply_flow_narrowing(node.orelse, node.test, positive=False)
                for stmt in node.orelse:
                    self.visit(stmt)

                for var, original_val in else_remapped.items():
                     if original_val is None:
                          if var in self.name_remap: del self.name_remap[var]
                     else:
                          self.name_remap[var] = original_val

                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
        else:
            if narrow_else or (node.orelse and not is_elif):
                # This part is a bit tricky: if there was no explicit else in Python,
                # but we have a narrow_else, we still emit an else block in V.
                # However, if there IS an orelse (else/elif), we already handled it above.
                pass

            if narrow_else:
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                self.output.append(f"{self._indent()}{narrow_else}")
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
            else:
                self.output.append(f"{self._indent()}}}")
