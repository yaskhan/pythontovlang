import ast
from typing import Any, List, Optional

class VNodeVisitor(ast.NodeVisitor):
    def __init__(self, type_inference):
        self.type_inference = type_inference
        self.output: List[str] = []
        self._indent_level = 0

    def _indent(self) -> str:
        return "    " * self._indent_level

    def visit_Module(self, node: ast.Module) -> str:
        for stmt in node.body:
            self.visit(stmt)
        return "\n".join(self.output)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        args_str_list = []
        for arg in node.args.args:
            arg_name = arg.arg
            # Use type inference map, default to 'int' if not found
            arg_type = self.type_inference.type_map.get(arg_name, "int")
            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)

        ret_type = "void"
        if node.returns:
             if isinstance(node.returns, ast.Name):
                  ret_type = node.returns.id
             elif isinstance(node.returns, ast.Constant) and isinstance(node.returns.value, str):
                  ret_type = node.returns.value

        decl = f"fn {node.name}({args_str}) {ret_type} {{"
        if ret_type == "void":
             decl = f"fn {node.name}({args_str}) {{"

        self.output.append(f"{self._indent()}{decl}")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Assign(self, node: ast.Assign) -> None:
        # Simplification: assuming single target
        target = node.targets[0]
        if isinstance(target, ast.Name):
            lhs = target.id
            rhs = self.visit(node.value)
            self.output.append(f"{self._indent()}{lhs} := {rhs}")

    def visit_Return(self, node: ast.Return) -> None:
        if node.value:
            val = self.visit(node.value)
            self.output.append(f"{self._indent()}return {val}")
        else:
            self.output.append(f"{self._indent()}return")

    def visit_Expr(self, node: ast.Expr) -> None:
        # Standalone expression statement
        val = self.visit(node.value)
        if val:
            self.output.append(f"{self._indent()}{val}")

    def visit_Call(self, node: ast.Call) -> str:
        func_name = self.visit(node.func)
        args = []
        for arg in node.args:
            val = self.visit(arg)
            if val is not None:
                args.append(str(val))
            else:
                args.append("/* unknown */")
        return f"{func_name}({', '.join(args)})"

    def visit_BinOp(self, node: ast.BinOp) -> str:
        left = self.visit(node.left)
        right = self.visit(node.right)
        op_map = {
            ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/",
            ast.Mod: "%", ast.Pow: "**"
        }
        op_str = op_map.get(type(node.op), "?")
        return f"{left} {op_str} {right}"

    def visit_Name(self, node: ast.Name) -> str:
        return node.id

    def visit_Constant(self, node: ast.Constant) -> str:
        val = node.value
        if isinstance(val, str):
            return f"'{val}'"
        elif isinstance(val, bool):
            return str(val).lower()
        elif val is None:
            return "none"
        return str(val)

    def generic_visit(self, node: ast.AST) -> Any:
        return super().generic_visit(node)
