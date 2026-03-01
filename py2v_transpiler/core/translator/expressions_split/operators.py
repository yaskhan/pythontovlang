import ast
from typing import List, Optional, Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v

class OperatorsMixin(TranslatorBase):
    def visit_BinOp(self, node: ast.BinOp) -> str:
        left_type = self._guess_type(node.left)
        right_type = self._guess_type(node.right)

        # Type-Directed Operator Overloading
        # Use inferred mypy static types to cast if needed.
        op_type = "void"
        loc_key = f"{getattr(node, 'lineno', 0)}:{getattr(node, 'col_offset', 0)}"
        if hasattr(self.type_inference, 'location_map') and loc_key in self.type_inference.location_map:
            v_type = self.type_inference.location_map[loc_key]
            if v_type != "void":
                 op_type = v_type

        left = self.visit(node.left)
        right = self.visit(node.right)

        # If mypy successfully inferred a concrete primitive numeric type (e.g. f64) for the operation,
        # and the operands' inferred types are not correctly matching or they are unknown ('Any'),
        # we can statically type the operator call by casting the operands.
        # This prevents boxing into 'Any' and relies on direct V operator calls.
        if op_type in ("int", "f64", "i64"):
             # For 'Any', we use a sum type assertion `(x as type)`.
             # For other unknown/primitive types, we use functional casting `type(x)`.
             if left_type == "Any":
                  left = f"({left} as {op_type})"
             elif left_type != op_type:
                  left = f"{op_type}({left})"

             if right_type == "Any":
                  right = f"({right} as {op_type})"
             elif right_type != op_type:
                  right = f"{op_type}({right})"

        if left_type == "PyComplex" and right_type != "PyComplex":
             right = f"py_complex(f64({right}), 0.0)"
        elif right_type == "PyComplex" and left_type != "PyComplex":
             left = f"py_complex(f64({left}), 0.0)"

        if isinstance(node.op, ast.MatMult):
             return f"{left}.matmul({right})"

        # Check for bytes formatting: b"%s" % b"a"
        if isinstance(node.op, ast.Mod):
             # Heuristic: check if left operand is likely bytes
             # We can check if `left_type` (from _guess_type) starts with `[]u8`?
             # `_guess_type` returns `int` usually unless constant bytes.
             # visit_Constant bytes returns `[{...}]`
             # Let's check `left_type`.
             if left_type == "[]u8" or (isinstance(node.left, ast.Constant) and isinstance(node.left.value, bytes)):
                 return f"py_bytes_format({left}, {right})"

        if isinstance(node.op, ast.Pow):
             self.emitter.add_import("math")
             # Check for negative exponent literal
             is_negative_literal = False
             if isinstance(node.right, ast.UnaryOp) and isinstance(node.right.op, ast.USub):
                 if isinstance(node.right.operand, ast.Constant) and isinstance(node.right.operand.value, (int, float)):
                      is_negative_literal = True
             elif isinstance(node.right, ast.Constant) and isinstance(node.right.value, (int, float)) and node.right.value < 0:
                  is_negative_literal = True

             # Check types
             is_float_op = (left_type == "f64" or right_type == "f64" or is_negative_literal)
             if is_float_op:
                  l_val = left
                  r_val = right
                  if left_type == "int":
                       l_val = f"f64({left})"
                  if right_type == "int":
                       r_val = f"f64({right})"
                  return f"math.pow({l_val}, {r_val})"
             else:
                  # Integer power
                  return f"math.powi({left}, {right})"

        if isinstance(node.op, ast.FloorDiv):
             # Floor division //
             # If float -> math.floor(a/b)
             # If int -> logic to handle negative operands
             self.emitter.add_import("math")
             if left_type == "int" and right_type == "int":
                  # Python's // on integers behaves like floor(a/b).
                  # V's / truncates.
                  # Formula: i64(math.floor(f64(a) / f64(b)))
                  # We use i64 to ensure it fits (assuming int is 64-bit or we don't care about 32-bit overflow here for now)
                  # or just cast to 'int' if V's int is 32-bit? V 'int' is 32-bit. 'i64' is 64-bit.
                  # Python 3 ints are arbitrary precision.
                  # Let's cast to `int` if inputs were `int` (as per guessing).
                  # Or stick to `i64` if we want to be safer?
                  # Let's use `int(...)` to match V's default int type.
                  return f"int(math.floor(f64({left}) / f64({right})))"
             else:
                  # Float floor div
                  # If we have floats, we return float.
                  # Python: 7.0 // 2 -> 3.0
                  # V: math.floor(7.0 / 2) -> 3.0
                  return f"math.floor({left} / {right})"

        op_map = {
            ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/",
            ast.Mod: "%",
            ast.BitAnd: "&", ast.BitOr: "|", ast.BitXor: "^",
            ast.LShift: "<<", ast.RShift: ">>"
        }

        # Check for string formatting: "string" % (args)
        if isinstance(node.op, ast.Mod):
             # Check if left is string
             is_string_fmt = False
             if isinstance(node.left, ast.Constant) and isinstance(node.left.value, str):
                 is_string_fmt = True
             elif left_type == "string":
                 is_string_fmt = True

             if is_string_fmt:
                 self.used_string_format = True
                 # Flatten arguments if tuple
                 fmt_args = right
                 if isinstance(node.right, ast.Tuple):
                      # We need individual args from visit(Tuple) which returns "[a, b]"
                      # This is tricky because visit(Tuple) returns a string representation of an array.
                      # We need the values.
                      # Re-visit elements of tuple individually.
                      arg_vals = [str(self.visit(elt)) for elt in node.right.elts]
                      fmt_args = ", ".join(arg_vals)

                 return f"py_string_format({left}, {fmt_args})"

        op_str = op_map.get(type(node.op), "?")
        return f"{left} {op_str} {right}"

    def visit_BoolOp(self, node: ast.BoolOp) -> str:
        op_map = {ast.And: "&&", ast.Or: "||"}
        op_str = op_map.get(type(node.op), "and")
        values = [str(self.visit(val)) for val in node.values]
        return f" {op_str} ".join(values)

    def visit_UnaryOp(self, node: ast.UnaryOp) -> str:
        operand = self.visit(node.operand)
        op_map = {
            ast.Not: "!", ast.UAdd: "+", ast.USub: "-",
            ast.Invert: "~"
        }
        op_str = op_map.get(type(node.op), "?")
        return f"{op_str}{operand}"

    def visit_Compare(self, node: ast.Compare) -> str:
        comparators = [self.visit(node.left)] + [self.visit(c) for c in node.comparators]
        ops_map = {
            ast.Eq: "==", ast.NotEq: "!=", ast.Lt: "<", ast.LtE: "<=",
            ast.Gt: ">", ast.GtE: ">=", ast.Is: "==", ast.IsNot: "!=",
            ast.In: "in", ast.NotIn: "!in"
        }

        if len(node.ops) == 1:
            left = comparators[0]
            right = comparators[1]
            op = node.ops[0]
            op_str = ops_map.get(type(op), "?")

            if isinstance(op, ast.Is) and str(right) == "none":
                 op_str = "=="
            elif isinstance(op, ast.IsNot) and str(right) == "none":
                 op_str = "!="

            return f"{left} {op_str} {right}"

        parts = []
        for i, op in enumerate(node.ops):
            left = comparators[i]
            right = comparators[i+1]
            op_str = ops_map.get(type(op), "?")

            if isinstance(op, ast.Is) and str(right) == "none":
                 op_str = "=="
            elif isinstance(op, ast.IsNot) and str(right) == "none":
                 op_str = "!="

            parts.append(f"({left} {op_str} {right})")

        return " && ".join(parts)
