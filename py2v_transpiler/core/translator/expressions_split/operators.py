import ast
import re
from typing import Any
from ..base import TranslatorBase

# Pre-compiled regular expressions for performance
_PLACEHOLDERS_RE = re.compile(r'%[sdfr]')
_PLACEHOLDERS_GROUPS_RE = re.compile(r'%([sdfr])')

# Static mapping for operators to improve performance
_BIN_OP_MAP = {
    ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/",
    ast.Mod: "%",
    ast.BitAnd: "&", ast.BitOr: "|", ast.BitXor: "^",
    ast.LShift: "<<", ast.RShift: ">>"
}

_UNARY_OP_MAP = {
    ast.UAdd: "+", ast.USub: "-",
    ast.Invert: "~"
}

_COMP_OP_MAP = {
    ast.Eq: "==", ast.NotEq: "!=", ast.Lt: "<", ast.LtE: "<=",
    ast.Gt: ">", ast.GtE: ">=", ast.Is: "==", ast.IsNot: "!=",
    ast.In: "in", ast.NotIn: "!in"
}

# Optimization: Lifted local op_map to module-level constant to avoid redundant dictionary creation in visit_BoolOp.
_BOOL_OP_STR_MAP = {ast.And: "&&", ast.Or: "||"}

class OperatorsMixin(TranslatorBase):
    def _should_use_is_none_type(self, typ: str, node: ast.AST) -> bool:
        if typ.startswith("?"): return False
        if typ.startswith("SumType_"): return True
        if typ.startswith("map[") and typ.endswith("]Any"): return True
        if typ == "Any":
            # Check if it was explicitly annotated as Any
            if isinstance(node, ast.Name) and node.id in getattr(self.type_inference, "explicit_any_types", set()):
                return True
            # Check if it has a location-based explicit Any
            loc_key = f"{getattr(node, 'id', '')}@{getattr(node, 'lineno', 0)}:{getattr(node, 'col_offset', 0)}"
            if loc_key in getattr(self.type_inference, "explicit_any_types", set()):
                return True
        return False

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

        # Support for array initialization: [element] * length
        if isinstance(node.op, ast.Mult):
            if left_type == "string":
                 return f"{self.visit(node.left)}.repeat({self.visit(node.right)})"
            if right_type == "string":
                 return f"{self.visit(node.right)}.repeat({self.visit(node.left)})"

            if isinstance(node.left, ast.List) and len(node.left.elts) == 1:
                init_node = node.left.elts[0]
                init_val = self.visit(init_node)
                length = self.visit(node.right)
                elem_type = self._guess_type(init_node)

                if init_val == "none" or init_val == "Any(NoneType{})":
                    init_val = "none"
                    expected_type = getattr(self, "current_assignment_type", None)
                    if expected_type and expected_type.startswith("[]"):
                        elem_type = expected_type[2:]
                        if not elem_type.startswith("?"):
                            elem_type = f"?{elem_type}"
                    else:
                        elem_type = "?Any"

                # Check if init_val is a literal collection or complex expression that V cannot handle in 'init:'
                if isinstance(init_node, (ast.List, ast.Tuple, ast.Dict, ast.Call, ast.BinOp)):
                     self.used_builtins.add("py_repeat")
                     return f"py_repeat({init_val}, {length})"

                return f"[]{elem_type}{{len: {length}, init: {init_val}}}"

            elif isinstance(node.right, ast.List) and len(node.right.elts) == 1:
                init_node = node.right.elts[0]
                init_val = self.visit(init_node)
                length = self.visit(node.left)
                elem_type = self._guess_type(init_node)

                if init_val == "none" or init_val == "Any(NoneType{})":
                    init_val = "none"
                    expected_type = getattr(self, "current_assignment_type", None)
                    if expected_type and expected_type.startswith("[]"):
                        elem_type = expected_type[2:]
                        if not elem_type.startswith("?"):
                            elem_type = f"?{elem_type}"
                    else:
                        elem_type = "?Any"

                if isinstance(init_node, (ast.List, ast.Tuple, ast.Dict, ast.Call, ast.BinOp)):
                     self.used_builtins.add("py_repeat")
                     return f"py_repeat({init_val}, {length})"

                return f"[]{elem_type}{{len: {length}, init: {init_val}}}"

            # General array repetition: [1, 2, 3] * n or list_var * n
            if left_type.startswith("[]") and right_type == "int":
                self.used_builtins.add("py_repeat_list")
                return f"py_repeat_list({self.visit(node.left)}, {self.visit(node.right)})"
            if right_type.startswith("[]") and left_type == "int":
                self.used_builtins.add("py_repeat_list")
                return f"py_repeat_list({self.visit(node.right)}, {self.visit(node.left)})"


        # If mypy  # the rest of the file follows unchanged
        left = self._visit_with_parens(node, node.left, is_right_operand=False)
        right = self._visit_with_parens(node, node.right, is_right_operand=True)

        # If mypy successfully inferred a concrete primitive numeric type (e.g. f64) for the operation,
        # and the operands' inferred types are not correctly matching or they are unknown ('Any'),
        # we can statically type the operator call by casting the operands.
        # This prevents boxing into 'Any' and relies on direct V operator calls.
        if op_type in ("int", "f64", "i64"):
             # For 'Any' or SumTypes, we use a sum type assertion `(x as type)`.
             # For other unknown/primitive types, we use functional casting `type(x)`.
             try:
                 l_base_type = self._guess_type(node.left, use_location=False)
                 r_base_type = self._guess_type(node.right, use_location=False)
             except TypeError:
                 l_base_type = self._guess_type(node.left)
                 r_base_type = self._guess_type(node.right)

             if l_base_type == "Any" or l_base_type.startswith("SumType_"):
                  # Avoid double casting if already casted
                  if not ("(" in left and " as " in left):
                       left = f"({left} as {op_type})"
             elif left_type != op_type:
                  left = f"{op_type}({left})"

             if r_base_type == "Any" or r_base_type.startswith("SumType_"):
                  # Avoid double casting if already casted
                  if not ("(" in right and " as " in right):
                       right = f"({right} as {op_type})"
             elif right_type != op_type:
                  right = f"{op_type}({right})"

        if left_type == "PyComplex" and right_type != "PyComplex":
             right = f"py_complex(f64({right}), 0.0)"
        elif right_type == "PyComplex" and left_type != "PyComplex":
             left = f"py_complex(f64({left}), 0.0)"

        if isinstance(node.op, ast.MatMult):
             return f"{left}.matmul({right})"

        # Handle set operations
        is_left_set = (left_type.startswith("map[") and left_type.endswith("]bool")) or left_type.startswith("datatypes.Set[")
        is_right_set = (right_type.startswith("map[") and right_type.endswith("]bool")) or right_type.startswith("datatypes.Set[")

        if is_left_set and is_right_set:
            if isinstance(node.op, ast.BitOr):
                self.used_builtins.add("py_set_union")
                return f"py_set_union({left}, {right})"
            elif isinstance(node.op, ast.BitAnd):
                self.used_builtins.add("py_set_intersection")
                return f"py_set_intersection({left}, {right})"
            elif isinstance(node.op, ast.Sub):
                self.used_builtins.add("py_set_difference")
                return f"py_set_difference({left}, {right})"
            elif isinstance(node.op, ast.BitXor):
                self.used_builtins.add("py_set_xor")
                return f"py_set_xor({left}, {right})"

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
                  return f"int(math.powi(f64({left}), {right}))"

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

        op_map = _BIN_OP_MAP

        # Check for string formatting: "string" % (args)
        if isinstance(node.op, ast.Mod):
             # Check if left is string
             is_string_fmt = False
             if isinstance(node.left, ast.Constant) and isinstance(node.left.value, str):
                 is_string_fmt = True
             elif left_type == "string":
                 is_string_fmt = True
             # Extended checks to robustly identify string formatting:
             if isinstance(node.left, ast.Name):
                 inferred = self.type_inference.resolve_type(node.left)
                 if inferred == "string":
                     is_string_fmt = True
                 elif node.left.id in self.type_inference.type_map and self.type_inference.type_map[node.left.id] == "string":
                     is_string_fmt = True
             elif isinstance(node.left, ast.BinOp) and self._guess_type(node.left) == "string":
                 is_string_fmt = True
             elif isinstance(node.left, ast.Attribute) and self._guess_type(node.left) == "string":
                 is_string_fmt = True

             # Fallback check: if we are still unsure about the left operand but we know the right operand is a string or a tuple
             # we can reasonably assume the user intended string formatting if the left operand is not definitively a number.
             if not is_string_fmt and left_type not in ("int", "f64", "float", "i64"):
                 if right_type == "string" or isinstance(node.right, ast.Tuple):
                     is_string_fmt = True

             if is_string_fmt:
                 self.used_string_format = True
                 # Try to convert to V interpolation if left is a constant string
                 if isinstance(node.left, ast.Constant) and isinstance(node.left.value, str):
                     fmt_str = node.left.value
                     # Handle simple %s, %d, %f, %r without complex flags
                     placeholders = _PLACEHOLDERS_RE.findall(fmt_str)

                     args = []
                     if isinstance(node.right, ast.Tuple):
                         args = node.right.elts
                     else:
                         args = [node.right]

                     if len(placeholders) == len(args) and '%%' not in fmt_str and fmt_str.count('%') == len(placeholders):
                         result_parts = []
                         last_pos = 0
                         arg_idx = 0
                         for match in _PLACEHOLDERS_GROUPS_RE.finditer(fmt_str):
                             result_parts.append(fmt_str[last_pos:match.start()])
                             spec = match.group(1)
                             v_arg = self.visit(args[arg_idx])
                             arg_idx += 1
                             if spec == 'r':
                                 self.used_builtins.add('py_repr')
                                 result_parts.append(f'${{py_repr({v_arg})}}')
                             else:
                                 result_parts.append(f'${{{v_arg}}}')
                             last_pos = match.end()
                         result_parts.append(fmt_str[last_pos:])

                         final_str = ''.join(result_parts)
                         bs = '\\'
                         double_bs = '\\\\'
                         final_str = final_str.replace(bs, double_bs)
                         return '`' + final_str + '`'
                 # Flatten arguments if tuple
                 fmt_args = right
                 if isinstance(node.right, ast.Tuple):
                      arg_vals = [str(self.visit(elt)) for elt in node.right.elts]
                      fmt_args = ", ".join(arg_vals)

                 return f"py_string_format({left}, {fmt_args})"

        op_str = op_map.get(type(node.op), "?")
        return f"{left} {op_str} {right}"

    def visit_BoolOp(self, node: ast.BoolOp) -> str:
        # Check if all operands are inherently boolean to safely use && and ||
        all_bools = True
        for val in node.values:
            if self._guess_type(val) != "bool":
                all_bools = False
                break

        # Also check if the expected return type is definitively boolean (like inside an `if`)
        # But `_guess_type` is unreliable for sum types assigned to untyped variables,
        # so relying only on operand types is safer.

        if all_bools:
            op_str = _BOOL_OP_STR_MAP.get(type(node.op), "and")
            values = []
            for i, val in enumerate(node.values):
                values.append(self._wrap_bool(val, parent=node, is_right_operand=(i > 0)))
            return f" {op_str} ".join(values)
        else:
            # For non-boolean context, evaluate left to right
            # Since V if expressions can't directly inline assignments of x without re-evaluating,
            # we rely on V's `or` block if `x` is Optional? No, V `or` is for Option/Result.
            # We must output `if bool(x) { x } else { y }`.
            # Note: `bool(x)` uses `self._wrap_bool`.

            ret_type = self._guess_type(node)
            if ret_type == "unknown" or getattr(self, "current_assignment_type", None) == "Any":
                ret_type = "Any"

            # Need to figure out a common return type if branches differ
            # Since V requires identical types, we check the types of all branches
            branch_types = [self._guess_type(v) for v in node.values]
            if len(set(branch_types)) > 1:
                ret_type = "Any"

            # Helper to recursively build nested if expressions
            def build_boolop(vals, is_and):
                if len(vals) == 1:
                    val_str = self.visit(vals[0])
                    v_type = self._guess_type(vals[0])
                    if ret_type == "Any" and "Any" not in v_type and not val_str.startswith("Any("):
                        if v_type.startswith("?"): return f"Any({val_str}!)"
                        return f"Any({val_str})"
                    return val_str
                left = vals[0]
                right_expr = build_boolop(vals[1:], is_and)

                left_cond = self._wrap_bool(left)
                left_val = self.visit(left)
                left_type = self._guess_type(left)
                if ret_type == "Any" and "Any" not in left_type and not left_val.startswith("Any("):
                    if left_type.startswith("?"): left_val = f"Any({left_val}!)"
                    else: left_val = f"Any({left_val})"

                if is_and:
                    # x and y -> if x { y } else { x }
                    return f"if {left_cond} {{ {right_expr} }} else {{ {left_val} }}"
                else:
                    # x or y -> if x { x } else { y }
                    return f"if {left_cond} {{ {left_val} }} else {{ {right_expr} }}"

            is_and = isinstance(node.op, ast.And)
            return build_boolop(node.values, is_and)

    def visit_UnaryOp(self, node: ast.UnaryOp) -> str:
        if isinstance(node.op, ast.Not):
             return self._wrap_bool(node.operand, invert=True)

        operand = self._visit_with_parens(node, node.operand, is_right_operand=True)
        op_str = _UNARY_OP_MAP.get(type(node.op), "?")
        return f"{op_str}{operand}"

    def visit_Compare(self, node: ast.Compare) -> str:
        comparators = [self.visit(node.left)] + [self.visit(c) for c in node.comparators]
        ops_map = _COMP_OP_MAP

        def is_none_node(n: ast.AST) -> bool:
            if isinstance(n, ast.Constant) and n.value is None: return True
            if isinstance(n, ast.Name) and n.id in ("None", "none"): return True
            return False

        if len(node.ops) == 1:
            left = comparators[0]
            right = comparators[1]
            op = node.ops[0]
            op_str = ops_map.get(type(op), "?")
            left_type = self._guess_type(node.left)

            if isinstance(op, (ast.Is, ast.Eq)) and is_none_node(node.comparators[0]):
                 if is_none_node(node.left):
                     return "true"
                 if self._should_use_is_none_type(left_type, node.left):
                      return f"(({left}) is NoneType)" if str(left).endswith("}") else f"({left}) is NoneType"
                 return f"{left} == none"
            elif isinstance(op, (ast.IsNot, ast.NotEq)) and is_none_node(node.comparators[0]):
                 if is_none_node(node.left):
                     return "false"
                 if self._should_use_is_none_type(left_type, node.left):
                      return f"(({left}) !is NoneType)" if str(left).endswith("}") else f"({left}) !is NoneType"
                 return f"{left} != none"
            elif isinstance(op, (ast.Is, ast.Eq)) and is_none_node(node.left):
                 right_type = self._guess_type(node.comparators[0])
                 if self._should_use_is_none_type(right_type, node.comparators[0]):
                      return f"(({right}) is NoneType)" if str(right).endswith("}") else f"({right}) is NoneType"
                 return f"none == {right}"
            elif isinstance(op, (ast.IsNot, ast.NotEq)) and is_none_node(node.left):
                 right_type = self._guess_type(node.comparators[0])
                 if self._should_use_is_none_type(right_type, node.comparators[0]):
                      return f"(({right}) !is NoneType)" if str(right).endswith("}") else f"({right}) !is NoneType"
                 return f"none != {right}"
            elif isinstance(op, ast.In) and is_none_node(node.left):
                 right_type = self._guess_type(node.comparators[0])
                 if right_type.startswith("map["):
                      return f"none in {right}"
                 return f"{right}.any(it == none)"
            elif isinstance(op, ast.NotIn) and is_none_node(node.left):
                 right_type = self._guess_type(node.comparators[0])
                 if right_type.startswith("map["):
                      return f"none !in {right}"
                 return f"!{right}.any(it == none)"

            # Set comparison
            if (left_type.startswith("map[") and left_type.endswith("]bool")) or left_type.startswith("datatypes.Set["):
                if isinstance(op, ast.LtE):
                    self.used_builtins.add("py_set_subset")
                    return f"py_set_subset({left}, {right})"
                elif isinstance(op, ast.Lt):
                    self.used_builtins.add("py_set_strict_subset")
                    return f"py_set_strict_subset({left}, {right})"
                elif isinstance(op, ast.GtE):
                    self.used_builtins.add("py_set_superset")
                    return f"py_set_superset({left}, {right})"
                elif isinstance(op, ast.Gt):
                    self.used_builtins.add("py_set_strict_superset")
                    return f"py_set_strict_superset({left}, {right})"

            if isinstance(op, ast.Is):
                 self.used_builtins.add("py_is_identical")
                 return f"py_is_identical({left}, {right})"
            if isinstance(op, ast.IsNot):
                 self.used_builtins.add("py_is_identical")
                 return f"!py_is_identical({left}, {right})"

            return f"{left} {op_str} {right}"

        parts = []
        for i, op in enumerate(node.ops):
            left = comparators[i]
            right = comparators[i+1]
            op_str = ops_map.get(type(op), "?")
            left_node = node.left if i == 0 else node.comparators[i-1]
            right_node = node.comparators[i]
            left_type = self._guess_type(left_node)

            if isinstance(op, (ast.Is, ast.Eq)) and is_none_node(right_node):
                 if is_none_node(left_node):
                      parts.append("true")
                      continue
                 if self._should_use_is_none_type(left_type, left_node):
                      parts.append(f"(({left}) is NoneType)" if str(left).endswith("}") else f"({left}) is NoneType")
                      continue
                 parts.append(f"({left} == none)")
            elif isinstance(op, (ast.IsNot, ast.NotEq)) and is_none_node(right_node):
                 if is_none_node(left_node):
                      parts.append("false")
                      continue
                 if self._should_use_is_none_type(left_type, left_node):
                      parts.append(f"(({left}) !is NoneType)" if str(left).endswith("}") else f"({left}) !is NoneType")
                      continue
                 parts.append(f"({left} != none)")
            elif isinstance(op, (ast.Is, ast.Eq)) and is_none_node(left_node):
                 right_type = self._guess_type(right_node)
                 if self._should_use_is_none_type(right_type, right_node):
                      parts.append(f"(({right}) is NoneType)" if str(right).endswith("}") else f"({right}) is NoneType")
                      continue
                 parts.append(f"(none == {right})")
            elif isinstance(op, (ast.IsNot, ast.NotEq)) and is_none_node(left_node):
                 right_type = self._guess_type(right_node)
                 if self._should_use_is_none_type(right_type, right_node):
                      parts.append(f"(({right}) !is NoneType)" if str(right).endswith("}") else f"({right}) !is NoneType")
                      continue
                 parts.append(f"(none != {right})")
            elif isinstance(op, ast.In) and is_none_node(left_node):
                 right_type = self._guess_type(node.comparators[i])
                 if right_type.startswith("map["):
                      parts.append(f"(none in {right})")
                 else:
                      parts.append(f"({right}.any(it == none))")
            elif isinstance(op, ast.NotIn) and is_none_node(left_node):
                 right_type = self._guess_type(node.comparators[i])
                 if right_type.startswith("map["):
                      parts.append(f"(none !in {right})")
                 else:
                      parts.append(f"(!{right}.any(it == none))")
            elif isinstance(op, ast.Is):
                 self.used_builtins.add("py_is_identical")
                 parts.append(f"py_is_identical({left}, {right})")
            elif isinstance(op, ast.IsNot):
                 self.used_builtins.add("py_is_identical")
                 parts.append(f"!py_is_identical({left}, {right})")
            else:
                 parts.append(f"({left} {op_str} {right})")

        return " && ".join(parts)
