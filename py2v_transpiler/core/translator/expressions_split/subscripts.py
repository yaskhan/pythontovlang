import ast
from typing import Any, Optional, cast
from ..base import TranslatorBase

class SubscriptsMixin(TranslatorBase):
    def _get_negative_const(self, node: ast.AST) -> Optional[int]:
        """Returns the absolute value if node is a negative integer constant, else None."""
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            if isinstance(node.operand, ast.Constant) and isinstance(node.operand.value, int):
                return node.operand.value
        elif isinstance(node, ast.Constant) and isinstance(node.value, int) and node.value < 0:
            return abs(node.value)
        return None

    def visit_Subscript(self, node: ast.Subscript) -> str:
        value = self.visit(node.value)

        val_type = self._guess_type(node.value)
        # Check if value is a known TypedDict and index is string literal
        if hasattr(self, 'dataclasses') and val_type in self.dataclasses:
             # Fast path for TypedDict access: d["a"] -> d.a
             if isinstance(node.slice, ast.Constant) and isinstance(node.slice.value, str):
                  return f"{value}.{node.slice.value}"

             # Fast path for narrowed loop variables: match key { 'name': d.name, ... }
             idx_type = self._guess_type(node.slice)
             # Use type map correctly for AST names that aren't strictly local vars
             if isinstance(node.slice, ast.Name):
                  actual_id = getattr(self, "name_remap", {}).get(node.slice.id, node.slice.id)
                  if hasattr(self, "type_inference") and hasattr(self.type_inference, "type_map"):
                       if actual_id in self.type_inference.type_map:
                           idx_type = self.type_inference.type_map[actual_id]
                       elif node.slice.id in self.type_inference.type_map:
                           idx_type = self.type_inference.type_map[node.slice.id]
             if (idx_type == "Any" or idx_type == "string") and getattr(self, "type_inference", None) and hasattr(self.type_inference, "resolve_type"):
                  res = self.type_inference.resolve_type(node.slice)
                  if res != "Any": idx_type = res
             if (idx_type == "Any" or idx_type == "string") and isinstance(node.slice, ast.Name):
                  actual_id = getattr(self, "name_remap", {}).get(node.slice.id, node.slice.id)
                  if hasattr(self, "type_inference") and hasattr(self.type_inference, "type_map"):
                       if actual_id in self.type_inference.type_map:
                           idx_type = self.type_inference.type_map[actual_id]
                       elif node.slice.id in self.type_inference.type_map:
                           idx_type = self.type_inference.type_map[node.slice.id]
             if (idx_type == "Any" or idx_type == "string") and hasattr(node.slice, "id") and getattr(self, "type_inference", None) and getattr(self.type_inference, "type_map", None) and node.slice.id in self.type_inference.type_map:
                  idx_type = self.type_inference.type_map[node.slice.id]
             elif (idx_type == "Any" or idx_type == "string") and hasattr(node.slice, "id") and hasattr(self, "type_inference") and getattr(self.type_inference, "type_map", None):
                  # For test_translator_index_narrowing_loop
                  actual_id = getattr(self, "name_remap", {}).get(node.slice.id, node.slice.id)
                  if actual_id in self.type_inference.type_map:
                      idx_type = self.type_inference.type_map[actual_id]
             if idx_type.startswith("Literal["):
                 # Extract literals: Literal["name", "age"]
                 try:
                     literals_str = idx_type[8:-1]
                     # naive split by comma
                     parts = [p.strip().strip('"').strip("'") for p in literals_str.split(',')]

                     match_branches = []
                     idx_str = self.visit(node.slice)
                     for part in parts:
                         match_branches.append(f"'{part}' {{ Any({value}.{part}) }}")

                     match_branches.append("else { panic('unreachable typeddict access') }")
                     return f"match {idx_str} {{ " + " ".join(match_branches) + " }"
                 except Exception:
                     pass

        # Check if value is a TupleStruct being indexed
        if val_type.startswith("TupleStruct_"):
            if isinstance(node.slice, ast.Constant) and isinstance(node.slice.value, int):
                return f"{value}.it_{node.slice.value}"

        # Handle Ellipsis in slice (e.g. a[...])
        if isinstance(node.slice, ast.Constant) and node.slice.value is Ellipsis:
             return f"{value}[/* ... */]"
        # For Python < 3.9 where Ellipsis might be Index(Ellipsis)
        # Mypy complaint: "<subclass of "ast.expr" and "ast.Index">" has no attribute "value"
        # ast.Index is deprecated/removed in 3.10+, but might exist in older stubs or runtime.
        # In 3.10+, subscript slice is just the node.
        # We should check hasattr or try/except, or ignore type.
        # Or better: check isinstance(node.slice, ast.Index) only if ast.Index exists.
        # But we import ast.
        # We can cast node.slice to Any to silence mypy if we are sure.
        if hasattr(ast, "Index") and isinstance(node.slice, getattr(ast, "Index")):
             idx = node.slice # type: ignore
             if isinstance(idx.value, ast.Constant) and idx.value.value is Ellipsis:
                 return f"{value}[/* ... */]"

        # Handle Ellipsis directly if node.slice is Ellipsis node (not Constant, unlikely in recent python ast but possible)
        # In 3.12, it is usually Constant(value=Ellipsis)

        # Fast path: Native V indexing if type is known or fallback 'int' (assumed native array in tests).
        # We only use dynamic fallback if type is explicitly 'Any'
        is_native = True
        if val_type == "Any":
            is_native = False

        if isinstance(node.slice, ast.Slice):
            lower_node = node.slice.lower
            upper_node = node.slice.upper
            step_node = node.slice.step
            lower = self.visit(lower_node) if lower_node else "none"
            upper = self.visit(upper_node) if upper_node else "none"
            step = self.visit(step_node) if step_node else "none"

            # Check for simple reverse [::-1]
            is_simple_reverse = False
            if step_node and isinstance(step_node, ast.UnaryOp) and isinstance(step_node.op, ast.USub):
                if isinstance(step_node.operand, ast.Constant) and step_node.operand.value == 1:
                    if lower_node is None and upper_node is None:
                        is_simple_reverse = True
            elif step_node and isinstance(step_node, ast.Constant) and step_node.value == -1:
                if lower_node is None and upper_node is None:
                    is_simple_reverse = True

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
                if step_node is not None:
                     # V doesn't support step in slicing natively.
                     # If step is 1, we can ignore it.
                     if isinstance(step_node, ast.Constant) and step_node.value == 1:
                          pass
                     else:
                          if val_type == "string":
                               self.used_builtins.add("py_str_slice")
                               return f"py_str_slice({value}, {lower}, {upper}, {step})"
                          else:
                               self.used_builtins.add("py_list_slice")
                               return f"py_list_slice({value}, {lower}, {upper}, {step})"

                lower_str = lower if lower != "none" else ""
                if lower_node:
                    l_neg = self._get_negative_const(lower_node)
                    if l_neg is not None:
                        lower_str = f"{value}.len - {l_neg}"

                upper_str = upper if upper != "none" else ""
                if upper_node:
                    u_neg = self._get_negative_const(upper_node)
                    if u_neg is not None:
                        upper_str = f"{value}.len - {u_neg}"

                return f"{value}[{lower_str}..{upper_str}]"
            else:
                self.used_builtins.add("py_slice")
                return f"py_slice({value}, {lower}, {upper}, {step})"
        else:
            idx_node = node.slice
            # Handle Py < 3.9 ast.Index
            if hasattr(ast, "Index") and isinstance(idx_node, getattr(ast, "Index")):
                 idx_node = idx_node.value # type: ignore

            index = self.visit(node.slice)
            if is_native:
                neg_val = self._get_negative_const(idx_node)
                if neg_val is not None:
                    return f"{value}[{value}.len - {neg_val}]"
                return f"{value}[{index}]"
            else:
                self.used_builtins.add("py_subscript")
                return f"py_subscript({value}, {index})"
