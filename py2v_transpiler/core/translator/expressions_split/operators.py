import ast
import re
from typing import Any, List
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

_CAST_TYPES = {"int", "f64", "i64"}
_SET_BIN_OPS = {ast.BitOr, ast.BitAnd, ast.Sub, ast.BitXor}

# Optimization: Lifted is_none_node to module level to avoid repeated function definition in visit_Compare.
# Using type() for faster matching than isinstance().
def _is_none_node(n: ast.AST) -> bool:
    t = type(n)
    if t is ast.Constant: return n.value is None  # type: ignore
    if t is ast.Name: return n.id in ("None", "none")  # type: ignore
    return False

class OperatorsMixin(TranslatorBase):
    def _should_use_is_none_type(self, typ: str, node: ast.AST) -> bool:
        if not typ: return False
        c0 = typ[0]
        if c0 == "?": return False
        if c0 == "S" and typ.startswith("SumType_"): return True
        if c0 == "m" and typ.startswith("map[") and typ.endswith("]Any"): return True
        if typ == "Any":
            # Check if it was explicitly annotated as Any
            # Optimization: Hoisted the explicit_any_types lookup to avoid repeated getattr calls.
            explicit_any: set[Any] = getattr(self.type_inference, "explicit_any_types", set())
            if not explicit_any:
                return False

            if isinstance(node, ast.Name) and node.id in explicit_any:
                return True
            # Check if it has a location-based explicit Any
            lineno = getattr(node, 'lineno', None)
            if lineno is not None:
                col_offset = getattr(node, 'col_offset', 0)
                loc_tuple = (lineno, col_offset)
                if loc_tuple in explicit_any:
                    return True
                if isinstance(node, ast.Name) and (node.id, loc_tuple) in explicit_any:
                    return True
                # Backward compatibility for mocks
                loc_str = f"{lineno}:{col_offset}"
                if loc_str in explicit_any:
                    return True
                if isinstance(node, ast.Name) and f"{node.id}@{loc_str}" in explicit_any:
                    return True
        return False

    def visit_BinOp(self, node: ast.BinOp) -> str:
        left_type = self._guess_type(node.left)
        right_type = self._guess_type(node.right)
        op_type_obj = type(node.op)

        if op_type_obj is ast.Mult:
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

            if left_type.startswith("[]") and right_type == "int":
                self.used_builtins.add("py_repeat_list")
                return f"py_repeat_list({self.visit(node.left)}, {self.visit(node.right)})"
            if right_type.startswith("[]") and left_type == "int":
                self.used_builtins.add("py_repeat_list")
                return f"py_repeat_list({self.visit(node.right)}, {self.visit(node.left)})"

        op_type = "void"
        loc_tuple = (getattr(node, 'lineno', 0), getattr(node, 'col_offset', 0))
        if hasattr(self.type_inference, 'location_map'):
            if loc_tuple in self.type_inference.location_map:
                v_type = self.type_inference.location_map[loc_tuple]
                if v_type != "void":
                     op_type = v_type
            else:
                loc_str = f"{loc_tuple[0]}:{loc_tuple[1]}"
                if loc_str in self.type_inference.location_map:
                    v_type = self.type_inference.location_map[loc_str]
                    if v_type != "void":
                         op_type = v_type

        left = self._visit_with_parens(node, node.left, is_right_operand=False)
        right = self._visit_with_parens(node, node.right, is_right_operand=True)

        if op_type in _CAST_TYPES:
             try:
                 l_base_type = self._guess_type(node.left, use_location=False)
                 r_base_type = self._guess_type(node.right, use_location=False)
             except TypeError:
                 l_base_type = left_type
                 r_base_type = right_type

             if l_base_type == "Any" or l_base_type.startswith("SumType_"):
                  if not ("(" in left and " as " in left):
                       left = f"({left} as {op_type})"
             elif left_type != op_type:
                  left = f"{op_type}({left})"

             if r_base_type == "Any" or r_base_type.startswith("SumType_"):
                  if not ("(" in right and " as " in right):
                       right = f"({right} as {op_type})"
             elif right_type != op_type:
                  right = f"{op_type}({right})"

        if left_type == "PyComplex" and right_type != "PyComplex":
             right = f"py_complex(f64({right}), 0.0)"
        elif right_type == "PyComplex" and left_type != "PyComplex":
             left = f"py_complex(f64({left}), 0.0)"

        if op_type_obj is ast.MatMult:
             return f"{left}.matmul({right})"

        if op_type_obj in _SET_BIN_OPS:
            is_left_set = (left_type.startswith("map[") and left_type.endswith("]bool")) or left_type.startswith("datatypes.Set[")
            is_right_set = (right_type.startswith("map[") and right_type.endswith("]bool")) or right_type.startswith("datatypes.Set[")

            if is_left_set and is_right_set:
                if op_type_obj is ast.BitOr:
                    self.used_builtins.add("py_set_union")
                    return f"py_set_union({left}, {right})"
                elif op_type_obj is ast.BitAnd:
                    self.used_builtins.add("py_set_intersection")
                    return f"py_set_intersection({left}, {right})"
                elif op_type_obj is ast.Sub:
                    self.used_builtins.add("py_set_difference")
                    return f"py_set_difference({left}, {right})"
                elif op_type_obj is ast.BitXor:
                    self.used_builtins.add("py_set_xor")
                    return f"py_set_xor({left}, {right})"

        if op_type_obj is ast.Mod:
             if left_type == "[]u8" or (isinstance(node.left, ast.Constant) and isinstance(node.left.value, bytes)):
                 return f"py_bytes_format({left}, {right})"

        if op_type_obj is ast.Pow:
             self.emitter.add_import("math")
             is_negative_literal = False
             if isinstance(node.right, ast.UnaryOp) and isinstance(node.right.op, ast.USub):
                 if isinstance(node.right.operand, ast.Constant) and isinstance(node.right.operand.value, (int, float)):
                      is_negative_literal = True
             elif isinstance(node.right, ast.Constant) and isinstance(node.right.value, (int, float)) and node.right.value < 0:
                  is_negative_literal = True

             is_float_op = (left_type == "f64" or right_type == "f64" or is_negative_literal)
             if is_float_op:
                  l_val = left
                  r_val = right
                  if left_type == "int": l_val = f"f64({left})"
                  if right_type == "int": r_val = f"f64({right})"
                  return f"math.pow({l_val}, {r_val})"
             else:
                  return f"int(math.powi(f64({left}), {right}))"

        if op_type_obj is ast.FloorDiv:
             self.emitter.add_import("math")
             if left_type == "int" and right_type == "int":
                  return f"int(math.floor(f64({left}) / f64({right})))"
             else:
                  return f"math.floor({left} / {right})"

        if op_type_obj is ast.Mod:
             is_string_fmt = (left_type == "string")
             if not is_string_fmt and isinstance(node.left, ast.Constant) and isinstance(node.left.value, str):
                 is_string_fmt = True

             if not is_string_fmt and left_type not in ("int", "f64", "float", "i64"):
                 if right_type == "string" or isinstance(node.right, ast.Tuple):
                     is_string_fmt = True

             if is_string_fmt:
                 self.used_string_format = True
                 if isinstance(node.left, ast.Constant) and isinstance(node.left.value, str):
                     fmt_str = node.left.value
                     placeholders = _PLACEHOLDERS_RE.findall(fmt_str)
                     args = node.right.elts if isinstance(node.right, ast.Tuple) else [node.right]

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
                         final_str = ''.join(result_parts).replace('\\', '\\\\')
                         return '`' + final_str + '`'

                 fmt_args = ", ".join([str(self.visit(elt)) for elt in node.right.elts]) if isinstance(node.right, ast.Tuple) else right
                 return f"py_string_format({left}, {fmt_args})"

        op_str = _BIN_OP_MAP.get(op_type_obj, "?")
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

        op_type_obj = type(node.op)
        if all_bools:
            op_str = _BOOL_OP_STR_MAP.get(op_type_obj, "and")
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

            is_and = (op_type_obj is ast.And)
            return self._build_boolop_expr(node.values, is_and, ret_type)

    def _build_boolop_expr(self, vals: List[ast.expr], is_and: bool, ret_type: str) -> str:
        """Recursive helper to build nested if expressions for Python's boolean operators."""
        if len(vals) == 1:
            val_str = self.visit(vals[0])
            v_type = self._guess_type(vals[0])
            if ret_type == "Any" and "Any" not in v_type and not val_str.startswith("Any("):
                if v_type.startswith("?"): return f"Any({val_str}!)"
                return f"Any({val_str})"
            return val_str
        left = vals[0]
        right_expr = self._build_boolop_expr(vals[1:], is_and, ret_type)

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

    def visit_UnaryOp(self, node: ast.UnaryOp) -> str:
        if type(node.op) is ast.Not:
             return self._wrap_bool(node.operand, invert=True)

        operand = self._visit_with_parens(node, node.operand, is_right_operand=True)
        op_str = _UNARY_OP_MAP.get(type(node.op), "?")
        return f"{op_str}{operand}"

    def visit_Compare(self, node: ast.Compare) -> str:
        comparators = [self.visit(node.left)] + [self.visit(c) for c in node.comparators]
        left_is_none = _is_none_node(node.left)
        comps_is_none = [_is_none_node(c) for c in node.comparators]
        left_type = self._guess_type(node.left)
        comp_types = [self._guess_type(c) for c in node.comparators]

        if len(node.ops) == 1:
            left, right = comparators[0], comparators[1]
            op_type = type(node.ops[0])
            op_str = _COMP_OP_MAP.get(op_type, "?")

            if op_type in (ast.Is, ast.Eq) and comps_is_none[0]:
                 if left_is_none: return "true"
                 if self._should_use_is_none_type(left_type, node.left):
                      return f"(({left}) is NoneType)" if str(left).endswith("}") else f"({left}) is NoneType"
                 return f"{left} == none"
            elif op_type in (ast.IsNot, ast.NotEq) and comps_is_none[0]:
                 if left_is_none: return "false"
                 if self._should_use_is_none_type(left_type, node.left):
                      return f"(({left}) !is NoneType)" if str(left).endswith("}") else f"({left}) !is NoneType"
                 return f"{left} != none"
            elif op_type in (ast.Is, ast.Eq) and left_is_none:
                 if self._should_use_is_none_type(comp_types[0], node.comparators[0]):
                      return f"(({right}) is NoneType)" if str(right).endswith("}") else f"({right}) is NoneType"
                 return f"none == {right}"
            elif op_type in (ast.IsNot, ast.NotEq) and left_is_none:
                 if self._should_use_is_none_type(comp_types[0], node.comparators[0]):
                      return f"(({right}) !is NoneType)" if str(right).endswith("}") else f"({right}) !is NoneType"
                 return f"none != {right}"
            elif op_type is ast.In and left_is_none:
                 if comp_types[0].startswith("map["): return f"none in {right}"
                 return f"{right}.any(it == none)"
            elif op_type is ast.NotIn and left_is_none:
                 if comp_types[0].startswith("map["): return f"none !in {right}"
                 return f"!{right}.any(it == none)"

            if (left_type.startswith("map[") and left_type.endswith("]bool")) or left_type.startswith("datatypes.Set["):
                if op_type is ast.LtE:
                    self.used_builtins.add("py_set_subset")
                    return f"py_set_subset({left}, {right})"
                elif op_type is ast.Lt:
                    self.used_builtins.add("py_set_strict_subset")
                    return f"py_set_strict_subset({left}, {right})"
                elif op_type is ast.GtE:
                    self.used_builtins.add("py_set_superset")
                    return f"py_set_superset({left}, {right})"
                elif op_type is ast.Gt:
                    self.used_builtins.add("py_set_strict_superset")
                    return f"py_set_strict_superset({left}, {right})"

            if op_type is ast.Is:
                 self.used_builtins.add("py_is_identical")
                 return f"py_is_identical({left}, {right})"
            if op_type is ast.IsNot:
                 self.used_builtins.add("py_is_identical")
                 return f"!py_is_identical({left}, {right})"

            return f"{left} {op_str} {right}"

        parts = []
        for i, op in enumerate(node.ops):
            left, right = comparators[i], comparators[i+1]
            op_type = type(op)
            op_str = _COMP_OP_MAP.get(op_type, "?")
            curr_left_is_none, curr_right_is_none = (left_is_none if i == 0 else comps_is_none[i-1]), comps_is_none[i]
            curr_left_type, curr_right_type = (left_type if i == 0 else comp_types[i-1]), comp_types[i]

            if op_type in (ast.Is, ast.Eq) and curr_right_is_none:
                 if curr_left_is_none: parts.append("true"); continue
                 if self._should_use_is_none_type(curr_left_type, (node.left if i == 0 else node.comparators[i-1])):
                      parts.append(f"(({left}) is NoneType)" if str(left).endswith("}") else f"({left}) is NoneType")
                      continue
                 parts.append(f"({left} == none)")
            elif op_type in (ast.IsNot, ast.NotEq) and curr_right_is_none:
                 if curr_left_is_none: parts.append("false"); continue
                 if self._should_use_is_none_type(curr_left_type, (node.left if i == 0 else node.comparators[i-1])):
                      parts.append(f"(({left}) !is NoneType)" if str(left).endswith("}") else f"({left}) !is NoneType")
                      continue
                 parts.append(f"({left} != none)")
            elif op_type in (ast.Is, ast.Eq) and curr_left_is_none:
                 if self._should_use_is_none_type(curr_right_type, node.comparators[i]):
                      parts.append(f"(({right}) is NoneType)" if str(right).endswith("}") else f"({right}) is NoneType")
                      continue
                 parts.append(f"(none == {right})")
            elif op_type in (ast.IsNot, ast.NotEq) and curr_left_is_none:
                 if self._should_use_is_none_type(curr_right_type, node.comparators[i]):
                      parts.append(f"(({right}) !is NoneType)" if str(right).endswith("}") else f"({right}) !is NoneType")
                      continue
                 parts.append(f"(none != {right})")
            elif op_type is ast.In and curr_left_is_none:
                 if curr_right_type.startswith("map["): parts.append(f"(none in {right})")
                 else: parts.append(f"({right}.any(it == none))")
            elif op_type is ast.NotIn and curr_left_is_none:
                 if curr_right_type.startswith("map["): parts.append(f"(none !in {right})")
                 else: parts.append(f"(!{right}.any(it == none))")
            elif op_type is ast.Is:
                 self.used_builtins.add("py_is_identical")
                 parts.append(f"py_is_identical({left}, {right})")
            elif op_type is ast.IsNot:
                 self.used_builtins.add("py_is_identical")
                 parts.append(f"!py_is_identical({left}, {right})")
            else:
                 parts.append(f"({left} {op_str} {right})")
        return " && ".join(parts)
