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
                    self.output.append(f"{self._indent()}mut {var} := {v_type}(none)")
                    self._local_vars_in_scope.add(var)

        # Check for TypeGuard / TypeIs narrowing
        narrow_if = None
        narrow_else = None

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

                            narrow_if = f"{arg_name} := ({arg_name} as {v_narrowed_type})"

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
                                    if v_remaining_type == "none" and orig_type.startswith("?"):
                                        narrow_else = f"{arg_name} := {orig_type}(none)"
                                    else:
                                        narrow_else = f"{arg_name} := ({arg_name} as {v_remaining_type})"

        # Check for walrus operator
        self._walrus_assignments = []
        test_expr = self.visit(node.test)

        node_type = self._guess_type(node.test)
        if node_type.startswith("[]") or node_type.startswith("map[") or node_type == "string":
            test_expr = f"{test_expr}.len > 0"

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

        if narrow_if:
             self.output.append(f"{self._indent()}{narrow_if}")

        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1

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
                if narrow_else:
                    self.output.append(f"{self._indent()}{narrow_else}")
                for stmt in node.orelse:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
        else:
            if narrow_else:
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                self.output.append(f"{self._indent()}{narrow_else}")
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
            else:
                self.output.append(f"{self._indent()}}}")
