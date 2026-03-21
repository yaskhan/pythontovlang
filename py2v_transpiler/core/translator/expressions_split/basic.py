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
        # Temporarily clear name_remap while generating the test expression to avoid
        # using narrowed variable names before they are declared or established.
        # We use a copy to preserve the original state for restoration.
        old_remap = self.name_remap.copy()
        self.name_remap.clear()
        try:
            test = self._wrap_bool(node.test)
        finally:
            self.name_remap = old_remap
        if node.msg is not None:
            msg = self.visit(node.msg)
            self.output.append(f"{self._indent()}assert {test}, {msg}")
        else:
            self.output.append(f"{self._indent()}assert {test}")

    def visit_IfExp(self, node: ast.IfExp) -> str:
        test = self._wrap_bool(node.test)
        body = self.visit(node.body)
        orelse = self.visit(node.orelse)
        return f"if {test} {{ {body} }} else {{ {orelse} }}"
