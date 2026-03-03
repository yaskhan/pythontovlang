import ast
from ..base import TranslatorBase

class ConditionalsMixin(TranslatorBase):
    """Обработка условных операторов: if, elif, else"""
    
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
