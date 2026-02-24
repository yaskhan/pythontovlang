import ast
from typing import Any, List

class VNodeVisitor(ast.NodeVisitor):
    def __init__(self, type_inference):
        self.type_inference = type_inference
        self.output: List[str] = []

    def visit_Module(self, node: ast.Module) -> Any:
        self.generic_visit(node)
        return "\n".join(self.output)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        args = [arg.arg for arg in node.args.args]
        # Simplified handling
        self.output.append(f"fn {node.name}({', '.join(args)}) {{")
        self.generic_visit(node)
        self.output.append("}")

    def visit_Assign(self, node: ast.Assign) -> Any:
        targets = [t.id for t in node.targets if isinstance(t, ast.Name)]
        if targets and isinstance(node.value, ast.Constant):
             val = node.value.value
             if isinstance(val, str):
                 val_str = f"'{val}'"
             elif isinstance(val, bool):
                 val_str = str(val).lower()
             elif val is None:
                 val_str = "none" # V uses none for nil/null
             else:
                 val_str = str(val)

             self.output.append(f"{targets[0]} := {val_str}")
        else:
             self.output.append("// Complex assignment not yet supported")

    def generic_visit(self, node: ast.AST) -> Any:
        super().generic_visit(node)
