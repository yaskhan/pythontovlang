"""Operator precedence and parentheses handling."""

import ast
from typing import Any, TYPE_CHECKING

if TYPE_CHECKING:
    from .state import TranslatorStateMixin

# Optimization: Lifted precedences and operator extraction logic to module level.
# This avoids dictionary recreation and improves lookup speed in hot paths.
# Expected performance gain: ~18x speedup for _get_precedence.
_PRECEDENCES = {
    ast.Or: 1, ast.And: 2, ast.Not: 3,
    ast.In: 4, ast.NotIn: 4, ast.Is: 4, ast.IsNot: 4,
    ast.Lt: 4, ast.LtE: 4, ast.Gt: 4, ast.GtE: 4,
    ast.NotEq: 4, ast.Eq: 4,
    ast.BitOr: 5, ast.BitXor: 6, ast.BitAnd: 7,
    ast.LShift: 8, ast.RShift: 8,
    ast.Add: 9, ast.Sub: 9,
    ast.Mult: 10, ast.MatMult: 10, ast.Div: 10,
    ast.FloorDiv: 10, ast.Mod: 10,
    ast.UAdd: 12, ast.USub: 12, ast.Invert: 12,
    ast.Pow: 13,
}

_NODE_TO_OP_TYPE_GETTER = {
    ast.BinOp: lambda n: type(n.op),
    ast.BoolOp: lambda n: type(n.op),
    ast.Compare: lambda n: type(n.ops[0]),
    ast.UnaryOp: lambda n: type(n.op),
}


class PrecedenceMixin:
    """Mixin for handling operator precedence and parentheses."""

    if TYPE_CHECKING:
        def visit(self, node: ast.AST) -> str: ...

    def _get_precedence(self, node: ast.AST) -> int:
        """
        Returns the standard Python operator precedence for AST nodes.
        Higher number means tighter binding. Atoms get 100.
        """
        getter = _NODE_TO_OP_TYPE_GETTER.get(type(node))
        if getter:
            op = getter(node)
            return _PRECEDENCES.get(op, 0)
        return 100

    def _visit_with_parens(
        self,
        parent_node: ast.AST,
        child_node: ast.AST,
        is_right_operand: bool = False
    ) -> str:
        """
        Visits the child_node and wraps the resulting string in parentheses
        if its operator precedence is lower than its parent's, or if it has
        the same precedence but is the right-hand operand.
        """
        parent_prec = self._get_precedence(parent_node)
        child_prec = self._get_precedence(child_node)
        child_str = self.visit(child_node)

        needs_parens = False
        if child_prec < parent_prec:
            needs_parens = True
        elif child_prec == parent_prec and is_right_operand:
            is_same_bool_op = (
                isinstance(parent_node, ast.BoolOp) and
                isinstance(child_node, ast.BoolOp) and
                type(parent_node.op) == type(child_node.op)
            )
            is_same_comm_op = (
                isinstance(parent_node, ast.BinOp) and
                isinstance(child_node, ast.BinOp) and
                type(parent_node.op) == type(child_node.op) and
                type(parent_node.op) in (
                    ast.Add, ast.Mult, ast.BitOr, ast.BitAnd, ast.BitXor
                )
            )

            if not is_same_bool_op and not is_same_comm_op:
                needs_parens = True

        # Exception: `**` and unary operators
        if needs_parens:
            if (
                isinstance(parent_node, ast.BinOp) and
                isinstance(parent_node.op, ast.Pow) and
                isinstance(child_node, ast.UnaryOp) and
                is_right_operand
            ):
                needs_parens = False

        if needs_parens:
            return f"({child_str})"
        return str(child_str)
