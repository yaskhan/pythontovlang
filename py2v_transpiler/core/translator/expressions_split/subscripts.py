import ast
from typing import Any
from ..base import TranslatorBase

class SubscriptsMixin(TranslatorBase):
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
             if idx_type.startswith("Literal["):
                 # Extract literals: Literal["name", "age"]
                 try:
                     literals_str = idx_type[8:-1]
                     # naive split by comma
                     parts = [p.strip().strip('"').strip("'") for p in literals_str.split(',')]

                     match_branches = []
                     idx_str = self.visit(node.slice)
                     for part in parts:
                         match_branches.append(f"'{part}' {{ ({value}.{part} as Any) }}")

                     match_branches.append("else { panic('unreachable typeddict access') }")
                     return f"match {idx_str} {{ " + " ".join(match_branches) + " }"
                 except Exception:
                     pass

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

        # Use tuple struct indexing if applicable
        if val_type.startswith("TupleStruct_"):
             if isinstance(node.slice, ast.Constant) and isinstance(node.slice.value, int):
                  return f"{value}.it_{node.slice.value}"

        # Fast path: Native V indexing if type is known or fallback 'int' (assumed native array in tests).
        # We only use dynamic fallback if type is explicitly 'Any'
        is_native = True
        if val_type == "Any":
            is_native = False

        if isinstance(node.slice, ast.Slice):
            lower = self.visit(node.slice.lower) if node.slice.lower else "none"
            upper = self.visit(node.slice.upper) if node.slice.upper else "none"

            if is_native:
                lower_str = lower if lower != "none" else ""
                upper_str = upper if upper != "none" else ""
                return f"{value}[{lower_str}..{upper_str}]"
            else:
                self.used_builtins.add("py_slice")
                return f"py_slice({value}, {lower}, {upper})"
        else:
            index = self.visit(node.slice)
            if is_native:
                # Use it_N for constant index on TupleStruct
                if val_type.startswith("TupleStruct_") and index.isdigit():
                     return f"{value}.it_{index}"
                return f"{value}[{index}]"
            else:
                self.used_builtins.add("py_subscript")
                return f"py_subscript({value}, {index})"
