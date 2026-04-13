import ast
from typing import Any, Optional, cast
from ..base import TranslatorBase

class SubscriptsMixin(TranslatorBase):
    def _get_negative_const(self, node: Optional[ast.AST]) -> Optional[int]:
        """Returns the absolute value if node is a negative integer constant, else None."""
        if node is None:
            return None
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            if isinstance(node.operand, ast.Constant) and isinstance(node.operand.value, int):
                return node.operand.value
        elif isinstance(node, ast.Constant) and isinstance(node.value, int) and node.value < 0:
            return abs(node.value)
        return None

    def visit_Subscript(self, node: ast.Subscript) -> str:
        value = self.visit(node.value)
        val_type = self._guess_type(node.value)

        # Normalize slice (Py < 3.9)
        idx_node = node.slice
        if hasattr(ast, "Index") and isinstance(idx_node, getattr(ast, "Index")):
             idx_node = idx_node.value  # type: ignore

        # Handle Ellipsis in slice (e.g. a[...])
        if isinstance(idx_node, ast.Constant) and idx_node.value is Ellipsis:
             return f"{value}[/* ... */]"

        # Check if value is a known TypedDict and index is string literal
        if hasattr(self, 'dataclasses') and val_type in self.dataclasses:
             # Fast path for TypedDict access: d["a"] -> d.a
             if isinstance(idx_node, ast.Constant) and isinstance(idx_node.value, str):
                  return f"{value}.{idx_node.value}"

             # Fast path for narrowed loop variables: match key { 'name': d.name, ... }
             idx_type = self._guess_type(idx_node)

             # Consolidate redundant TypedDict type lookups and narrowing logic.
             # Optimization: Avoid repeated getattr and dict probes by caching references.
             type_inf = getattr(self, "type_inference", None)
             type_map = getattr(type_inf, "type_map", {}) if type_inf else {}

             if isinstance(idx_node, ast.Name):
                  name_id = idx_node.id
                  actual_id = getattr(self, "name_remap", {}).get(name_id, name_id)

                  if actual_id in type_map:
                       idx_type = type_map[actual_id]
                  elif name_id in type_map:
                       idx_type = type_map[name_id]

                  if (idx_type == "Any" or idx_type == "string") and type_inf and hasattr(type_inf, "resolve_type"):
                       res = type_inf.resolve_type(idx_node)
                       if res != "Any":
                            idx_type = res

             if idx_type.startswith("Literal["):
                 # Extract literals: Literal["name", "age"]
                 try:
                     literals_str = idx_type[8:-1]
                     # naive split by comma
                     parts = [p.strip().strip('"').strip("'") for p in literals_str.split(',')]

                     match_branches = []
                     idx_str = self.visit(idx_node)
                     for part in parts:
                         match_branches.append(f"'{part}' {{ Any({value}.{part}) }}")

                     match_branches.append("else { panic('unreachable typeddict access') }")
                     return f"match {idx_str} {{ " + " ".join(match_branches) + " }"
                 except Exception:
                     pass

        # Check if value is a TupleStruct being indexed
        if val_type.startswith("TupleStruct_"):
            if isinstance(idx_node, ast.Constant) and isinstance(idx_node.value, int):
                return f"{value}.it_{idx_node.value}"

        # Fast path: Native V indexing if type is known or fallback 'int' (assumed native array in tests).
        # We only use dynamic fallback if type is explicitly 'Any'
        is_native = self._is_collection_type(val_type) or val_type != "Any"

        if isinstance(idx_node, ast.Slice):
            lower_node = idx_node.lower
            upper_node = idx_node.upper
            step_node = idx_node.step
            lower = self.visit(lower_node) if lower_node else "none"
            upper = self.visit(upper_node) if upper_node else "none"
            step = self.visit(step_node) if step_node else "none"

            # Check for simple reverse [::-1]
            # Optimization: Use _get_negative_const for concise reversal detection.
            is_simple_reverse = (
                lower_node is None and
                upper_node is None and
                self._get_negative_const(step_node) == 1
            )

            if is_simple_reverse:
                if val_type == "string":
                    self.used_builtins.add("py_str_reverse")
                    return f"py_str_reverse({value})"
                elif val_type.startswith("[]"):
                    self.used_builtins.add("py_list_reverse")
                    return f"py_list_reverse({value})"
                elif not is_native:
                    self.used_builtins.add("py_slice")
                    return f"py_slice({value}, {lower}, {upper}, {step})"

            if is_native:
                # To maintain compatibility with existing tests while ensuring safety:
                # 1. Full slice [:] -> [..]
                # 2. Slice with non-trivial step -> helper
                # 3. Slice with negative bounds -> helper (for clamping safety)
                # 4. Slice with non-constant bounds or variables -> helper
                # 5. Slice with positive constant bounds and NO step -> native [low..up]

                has_non_trivial_step = step_node is not None and not (isinstance(step_node, ast.Constant) and step_node.value == 1)

                is_simple_slice = True
                if has_non_trivial_step:
                    is_simple_slice = False

                lower_str = ""
                if lower_node:
                    l_neg = self._get_negative_const(lower_node)
                    if l_neg is not None:
                        is_simple_slice = False
                    elif isinstance(lower_node, ast.Constant) and isinstance(lower_node.value, int):
                        lower_str = str(lower_node.value)
                    else:
                        is_simple_slice = False

                upper_str = ""
                if upper_node:
                    u_neg = self._get_negative_const(upper_node)
                    if u_neg is not None:
                        is_simple_slice = False
                    elif isinstance(upper_node, ast.Constant) and isinstance(upper_node.value, int):
                        upper_str = str(upper_node.value)
                    else:
                        is_simple_slice = False

                if not is_simple_slice:
                    if val_type == "string":
                        self.used_builtins.add("py_str_slice")
                        return f"py_str_slice({value}, {lower}, {upper}, {step})"
                    else:
                        self.used_builtins.add("py_list_slice")
                        return f"py_list_slice({value}, {lower}, {upper}, {step})"

                return f"{value}[{lower_str}..{upper_str}]"
            else:
                self.used_builtins.add("py_slice")
                return f"py_slice({value}, {lower}, {upper}, {step})"
        else:
            index = self.visit(idx_node)
            if is_native:
                neg_val = self._get_negative_const(idx_node)
                if neg_val is not None:
                    return f"{value}[{value}.len - {neg_val}]"
                return f"{value}[{index}]"
            else:
                self.used_builtins.add("py_subscript")
                return f"py_subscript({value}, {index})"
