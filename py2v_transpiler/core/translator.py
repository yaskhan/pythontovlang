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

    def visit_If(self, node: ast.If) -> None:
        test_expr = self.visit(node.test)
        self.output.append(f"{self._indent()}if {test_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1

        if node.orelse:
            if len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If):
                # elif case
                self.output.append(f"{self._indent()}}} else {{")
                # Just treat as nested if for now to be safe
                self._indent_level += 1
                self.visit(node.orelse[0])
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
            else:
                self.output.append(f"{self._indent()}}} else {{")
                self._indent_level += 1
                for stmt in node.orelse:
                    self.visit(stmt)
                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
        else:
            self.output.append(f"{self._indent()}}}")

    def visit_While(self, node: ast.While) -> None:
        test_expr = self.visit(node.test)
        self.output.append(f"{self._indent()}for {test_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_For(self, node: ast.For) -> None:
        target = self.visit(node.target)
        iter_expr = self.visit(node.iter)

        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name) and node.iter.func.id == "range":
             args = node.iter.args
             start = "0"
             stop = "0"
             if len(args) == 1:
                  stop = self.visit(args[0])
             elif len(args) == 2:
                  start = self.visit(args[0])
                  stop = self.visit(args[1])

             iter_expr = f"{start}..{stop}"

        self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Compare(self, node: ast.Compare) -> str:
        left = self.visit(node.left)
        ops = {
            ast.Eq: "==", ast.NotEq: "!=", ast.Lt: "<", ast.LtE: "<=",
            ast.Gt: ">", ast.GtE: ">=", ast.Is: "==", ast.IsNot: "!=",
            ast.In: "in", ast.NotIn: "!in"
        }

        result = [str(left)]
        for op, comparator in zip(node.ops, node.comparators):
             op_str = ops.get(type(op), "?")
             comp_val = self.visit(comparator)
             result.append(f"{op_str} {comp_val}")

        return " ".join(result)

    def visit_BoolOp(self, node: ast.BoolOp) -> str:
        op_map = {ast.And: "&&", ast.Or: "||"}
        op_str = op_map.get(type(node.op), "and")
        values = [str(self.visit(val)) for val in node.values]
        return f" {op_str} ".join(values)

    def visit_UnaryOp(self, node: ast.UnaryOp) -> str:
        operand = self.visit(node.operand)
        op_map = {ast.Not: "!", ast.UAdd: "+", ast.USub: "-"}
        op_str = op_map.get(type(node.op), "?")
        return f"{op_str}{operand}"

    def visit_Break(self, node: ast.Break) -> None:
        self.output.append(f"{self._indent()}break")

    def visit_Continue(self, node: ast.Continue) -> None:
        self.output.append(f"{self._indent()}continue")

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
