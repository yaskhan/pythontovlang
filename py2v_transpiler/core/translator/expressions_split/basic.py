import ast
from ..base import TranslatorBase

class BasicExpressionsMixin(TranslatorBase):
    def visit_Expr(self, node: ast.Expr) -> None:
        val = self.visit(node.value)
        if val:
            self.output.append(f"{self._indent()}{val}")

    def visit_Starred(self, node: ast.Starred) -> str:
        val = self.visit(node.value)
        return f"...{val}"

    def visit_Assert(self, node: ast.Assert) -> None:
        test = self.visit(node.test)
        self.output.append(f"{self._indent()}assert {test}")

    def visit_IfExp(self, node: ast.IfExp) -> str:
        test = self.visit(node.test)
        body = self.visit(node.body)
        orelse = self.visit(node.orelse)
        return f"if {test} {{ {body} }} else {{ {orelse} }}"
