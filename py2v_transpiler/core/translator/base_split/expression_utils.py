"""Expression capture utilities."""

import ast
from typing import List, Tuple


class ExpressionUtilsMixin:
    """Mixin for expression capture utilities."""

    def _capture_value(self, node: ast.AST) -> Tuple[str, List[str]]:
        """
        Captures an expression into a temporary variable if it's not simple.
        Returns (expr_string, setup_statements).
        """
        if isinstance(node, (ast.Name, ast.Constant)):
            return self.visit(node), []

        tmp = self._create_temp()
        val_code = self.visit(node)
        return tmp, [f"{self._indent()}{tmp} := {val_code}"]

    def _capture_target(self, node: ast.AST) -> Tuple[str, List[str]]:
        """
        Prepares a target for AugAssign by capturing its components.
        Recurses on L-value bases (Attribute, Subscript) to preserve reference path.
        Returns (new_target_string, setup_statements).
        """
        if isinstance(node, ast.Name):
            return self.visit(node), []

        elif isinstance(node, ast.Attribute):
            if isinstance(node.value, (ast.Name, ast.Attribute, ast.Subscript)):
                base_expr, base_setup = self._capture_target(node.value)
            else:
                base_expr, base_setup = self._capture_value(node.value)

            return f"{base_expr}.{node.attr}", base_setup

        elif isinstance(node, ast.Subscript):
            if isinstance(node.value, (ast.Name, ast.Attribute, ast.Subscript)):
                base_expr, base_setup = self._capture_target(node.value)
            else:
                base_expr, base_setup = self._capture_value(node.value)

            idx_node = node.slice
            if hasattr(ast, "Index") and isinstance(idx_node, getattr(ast, "Index")):
                idx_node = idx_node.value

            idx_expr, idx_setup = self._capture_value(idx_node)
            return f"{base_expr}[{idx_expr}]", base_setup + idx_setup

        return self.visit(node), []
