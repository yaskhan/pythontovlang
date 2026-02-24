import ast
from typing import Any, List, Optional
from py2v_transpiler.core.generator import VCodeEmitter

class VNodeVisitor(ast.NodeVisitor):
    def __init__(self, type_inference):
        self.type_inference = type_inference
        # Use emitter for structured output
        self.emitter = VCodeEmitter()
        # Internal buffer for visiting blocks (functions, loops, etc.)
        self.output: List[str] = []
        self._indent_level = 0
        self.in_main = True # Flag to track if we are at top-level
        self.current_class: Optional[str] = None # Track if we are inside a class definition
        self._zip_counter = 0 # Counter for unique variable names in zip loops

    def _indent(self) -> str:
        return "    " * self._indent_level

    def visit_Module(self, node: ast.Module) -> str:
        for stmt in node.body:
            # Check if statement is top-level expression or assignment
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Import, ast.ImportFrom)):
                self.in_main = False
                self.visit(stmt)
                self.in_main = True
            else:
                # This is part of main body
                # We need to capture the output of this statement
                # But visit returns None and appends to self.output
                # So we need to manage self.output

                # Clear output buffer
                self.output = []
                self.visit(stmt)
                # Append buffer to main
                for line in self.output:
                    # Remove indentation if added by _indent() for main body
                    # Because generator adds indentation for main()
                    self.emitter.add_main_statement(line.strip())
                self.output = []

        return self.emitter.emit()

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self._visit_function_common(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self._visit_function_common(node, is_async=True)

    def _visit_function_common(self, node: Any, is_async: bool = False) -> None:
        # Save current state
        old_output = self.output
        self.output = []
        self._indent_level = 0

        is_method = self.current_class is not None
        # Ensure struct_name is always a string
        struct_name: str = self.current_class if self.current_class else ""

        args_str_list: List[str] = []
        receiver_str: str = ""

        args = node.args.args
        if is_method and args and args[0].arg == "self":
            # Handle 'self' - it becomes the receiver in V
            # fn (s Struct) method()
            receiver_str = f"({args[0].arg} {struct_name}) "
            args = args[1:] # Remove self from arguments list

        for arg in args:
            arg_name = arg.arg
            arg_type = self.type_inference.type_map.get(arg_name, "int")
            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)

        ret_type = "void"
        if node.returns:
             if isinstance(node.returns, ast.Name):
                  ret_type = node.returns.id
             elif isinstance(node.returns, ast.Constant) and isinstance(node.returns.value, str):
                  ret_type = node.returns.value

        func_name = node.name
        if func_name == "__init__":
            # Constructor logic: make it a static factory function for now
            # fn new_Struct(...) Struct
            func_name = f"new_{struct_name}"
            receiver_str = "" # Factory is static
            ret_type = struct_name
            # We need to implicitly return the struct instance, but that's complex logic.
            # For now, just change the name.

        decl = f"fn {receiver_str}{func_name}({args_str}) {ret_type} {{"
        if ret_type == "void":
             decl = f"fn {receiver_str}{func_name}({args_str}) {{"

        self.output.append(f"{decl}") # No indent for top level function
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append("}")

        # Add function to emitter
        self.emitter.add_function("\n".join(self.output))

        # Restore state
        self.output = old_output

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        # Map Python class to V struct
        struct_name = node.name
        self.current_class = struct_name

        # Extract fields from __init__ or class body annotations (simplified)
        fields = []
        methods = []

        for stmt in node.body:
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods.append(stmt)
            elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                # Class attribute with annotation -> struct field
                field_name = stmt.target.id
                field_type = "int" # default
                if isinstance(stmt.annotation, ast.Name):
                    field_type = stmt.annotation.id
                fields.append(f"    {field_name} {field_type}")

        struct_def = f"struct {struct_name} {{\n" + "\n".join(fields) + "\n}"
        self.emitter.add_struct(struct_def)

        # Visit methods to generate them as functions
        for method in methods:
            self.visit(method)

        self.current_class = None

    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            self.emitter.add_import(alias.name)

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        if node.module:
            self.emitter.add_import(node.module)

    def visit_Assign(self, node: ast.Assign) -> None:
        target = node.targets[0]
        lhs = ""
        if isinstance(target, ast.Name):
            lhs = target.id
        elif isinstance(target, ast.Attribute):
            # obj.attr = value
            lhs = f"{self.visit(target.value)}.{target.attr}"
        elif isinstance(target, ast.Subscript):
            # list[index] = value
            lhs = self.visit(target)

        if isinstance(node.value, ast.ListComp):
            self.visit_ListComp(node.value, target_var=lhs)
        else:
            rhs = self.visit(node.value)
            self.output.append(f"{self._indent()}{lhs} := {rhs}")

    def visit_ListComp(self, node: ast.ListComp, target_var: Optional[str] = None) -> None:
        if not target_var:
            self.output.append(f"{self._indent()}// List comprehension expression not supported inline yet")
            return

        self.output.append(f"{self._indent()}mut {target_var} := []int{{}}")

        gen = node.generators[0] # Handle first generator

        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name) and gen.iter.func.id == "zip":
             args = gen.iter.args
             if len(args) == 2:
                 self._zip_counter += 1
                 zip_id = self._zip_counter

                 it1 = self.visit(args[0])
                 it2 = self.visit(args[1])

                 var_it1 = f"_zip_it1_{zip_id}"
                 var_it2 = f"_zip_it2_{zip_id}"
                 var_i = f"_i_{zip_id}"
                 var_v1 = f"_v1_{zip_id}"
                 var_v2 = f"_v2_{zip_id}"

                 self.output.append(f"{self._indent()}{var_it1} := {it1}")
                 self.output.append(f"{self._indent()}{var_it2} := {it2}")

                 self.output.append(f"{self._indent()}for {var_i}, {var_v1} in {var_it1} {{")
                 self._indent_level += 1

                 self.output.append(f"{self._indent()}if {var_i} >= {var_it2}.len {{ break }}")
                 self.output.append(f"{self._indent()}{var_v2} := {var_it2}[{var_i}]")

                 if isinstance(gen.target, ast.Tuple) and len(gen.target.elts) == 2:
                     t1 = self.visit(gen.target.elts[0])
                     t2 = self.visit(gen.target.elts[1])
                     self.output.append(f"{self._indent()}{t1} := {var_v1}")
                     self.output.append(f"{self._indent()}{t2} := {var_v2}")
                 else:
                     target = self.visit(gen.target)
                     self.output.append(f"{self._indent()}{target} := [{var_v1}, {var_v2}]")

                 for if_expr in gen.ifs:
                    cond = self.visit(if_expr)
                    self.output.append(f"{self._indent()}if {cond} {{")
                    self._indent_level += 1

                 elt = self.visit(node.elt)
                 self.output.append(f"{self._indent()}{target_var} << {elt}")

                 for _ in gen.ifs:
                    self._indent_level -= 1
                    self.output.append(f"{self._indent()}}}")

                 self._indent_level -= 1
                 self.output.append(f"{self._indent()}}}")
                 return

        target = self.visit(gen.target)
        iter_expr = self.visit(gen.iter)

        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name):
             if gen.iter.func.id == "range":
                 args = gen.iter.args
                 start = "0"
                 stop = "0"
                 if len(args) == 1:
                      stop = self.visit(args[0])
                 elif len(args) == 2:
                      start = self.visit(args[0])
                      stop = self.visit(args[1])
                 iter_expr = f"{start}..{stop}"
             elif gen.iter.func.id == "enumerate":
                 if gen.iter.args:
                     iter_expr = self.visit(gen.iter.args[0])
                     # Handle target for enumerate: for i, v in items
                     if isinstance(gen.target, ast.Tuple):
                         # visit_Tuple returns [i, v], we need i, v
                         if target.startswith("[") and target.endswith("]"):
                             target = target[1:-1]
                     else:
                         self.output.append(f"{self._indent()}// TODO: handle enumerate with single target variable")

        self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
        self._indent_level += 1

        for if_expr in gen.ifs:
            cond = self.visit(if_expr)
            self.output.append(f"{self._indent()}if {cond} {{")
            self._indent_level += 1

        elt = self.visit(node.elt)
        self.output.append(f"{self._indent()}{target_var} << {elt}")

        for _ in gen.ifs:
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Dict(self, node: ast.Dict) -> str:
        if not node.keys:
            # Empty dict
            return "map[string]int{}" # Default fallback

        pairs = []
        for k, v in zip(node.keys, node.values):
            if k:
                key_str = self.visit(k)
                val_str = self.visit(v)
                pairs.append(f"{key_str}: {val_str}")
        return f"map[string]int{{{', '.join(pairs)}}}"

    def visit_Set(self, node: ast.Set) -> str:
        # {1, 2} -> map[int]bool{1: true, 2: true}
        # Simplified assumption that elements are ints
        elements = []
        for elt in node.elts:
            val = self.visit(elt)
            elements.append(f"{val}: true")

        return f"map[int]bool{{{', '.join(elements)}}}"

    def visit_List(self, node: ast.List) -> str:
        elements = [str(self.visit(elt)) for elt in node.elts]
        if not elements:
             return "[]int{}" # Placeholder for empty list
        return f"[{', '.join(elements)}]"

    def visit_Tuple(self, node: ast.Tuple) -> str:
        # Translate Tuple (a, b) to Array [a, b]
        elements = [str(self.visit(elt)) for elt in node.elts]
        return f"[{', '.join(elements)}]"

    def visit_Lambda(self, node: ast.Lambda) -> str:
        # lambda args: expr -> fn (args) { return expr }
        args_str_list = []
        for arg in node.args.args:
            arg_name = arg.arg
            arg_type = "int" # Default type for now
            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)
        body = self.visit(node.body)

        # Assuming return type is inferred or int for now
        # V anonymous functions: fn (a int) int { return a + 1 }
        return f"fn ({args_str}) int {{ return {body} }}"

    def visit_Yield(self, node: ast.Yield) -> str:
        # yield expr -> /* yield expr */
        val = ""
        if node.value:
            val = self.visit(node.value)
        return f"/* yield {val} */"

    def visit_YieldFrom(self, node: ast.YieldFrom) -> str:
        val = self.visit(node.value)
        return f"/* yield from {val} */"

    def visit_Await(self, node: ast.Await) -> str:
        # await foo() -> // await foo()
        val = self.visit(node.value)
        return f"/* await */ {val}"

    def visit_Assert(self, node: ast.Assert) -> None:
        test = self.visit(node.test)
        self.output.append(f"{self._indent()}assert {test}")

    def visit_Global(self, node: ast.Global) -> None:
        names = ", ".join(node.names)
        self.output.append(f"{self._indent()}// global {names}")

    def visit_Nonlocal(self, node: ast.Nonlocal) -> None:
        names = ", ".join(node.names)
        self.output.append(f"{self._indent()}// nonlocal {names}")

    def visit_Return(self, node: ast.Return) -> None:
        if node.value:
            val = self.visit(node.value)
            self.output.append(f"{self._indent()}return {val}")
        else:
            self.output.append(f"{self._indent()}return")

    def visit_Expr(self, node: ast.Expr) -> None:
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

    def visit_Attribute(self, node: ast.Attribute) -> str:
        obj = self.visit(node.value)
        return f"{obj}.{node.attr}"

    def visit_Subscript(self, node: ast.Subscript) -> str:
        value = self.visit(node.value)

        if isinstance(node.slice, ast.Slice):
            lower = self.visit(node.slice.lower) if node.slice.lower else ""
            upper = self.visit(node.slice.upper) if node.slice.upper else ""
            return f"{value}[{lower}..{upper}]"
        else:
            index = self.visit(node.slice)
            return f"{value}[{index}]"

    def visit_JoinedStr(self, node: ast.JoinedStr) -> str:
        parts = []
        for value in node.values:
            val = self.visit(value)
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                parts.append(value.value)
            else:
                parts.append(str(val))

        return f"'{''.join(parts)}'"

    def visit_FormattedValue(self, node: ast.FormattedValue) -> str:
        val = self.visit(node.value)
        return f"${{{val}}}"

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
        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name) and node.iter.func.id == "zip":
            # Handle zip(a, b)
            args = node.iter.args
            if len(args) == 2:
                self._zip_counter += 1
                zip_id = self._zip_counter

                it1 = self.visit(args[0])
                it2 = self.visit(args[1])

                var_it1 = f"_zip_it1_{zip_id}"
                var_it2 = f"_zip_it2_{zip_id}"
                var_i = f"_i_{zip_id}"
                var_v1 = f"_v1_{zip_id}"
                var_v2 = f"_v2_{zip_id}"

                self.output.append(f"{self._indent()}{var_it1} := {it1}")
                self.output.append(f"{self._indent()}{var_it2} := {it2}")

                self.output.append(f"{self._indent()}for {var_i}, {var_v1} in {var_it1} {{")
                self._indent_level += 1

                self.output.append(f"{self._indent()}if {var_i} >= {var_it2}.len {{ break }}")
                self.output.append(f"{self._indent()}{var_v2} := {var_it2}[{var_i}]")

                if isinstance(node.target, ast.Tuple) and len(node.target.elts) == 2:
                    t1 = self.visit(node.target.elts[0])
                    t2 = self.visit(node.target.elts[1])
                    self.output.append(f"{self._indent()}{t1} := {var_v1}")
                    self.output.append(f"{self._indent()}{t2} := {var_v2}")
                else:
                    target = self.visit(node.target)
                    self.output.append(f"{self._indent()}{target} := [{var_v1}, {var_v2}]")

                for stmt in node.body:
                    self.visit(stmt)

                self._indent_level -= 1
                self.output.append(f"{self._indent()}}}")
                return

        target = self.visit(node.target)
        iter_expr = self.visit(node.iter)

        if isinstance(node.iter, ast.Call) and isinstance(node.iter.func, ast.Name):
             if node.iter.func.id == "range":
                 args = node.iter.args
                 start = "0"
                 stop = "0"
                 if len(args) == 1:
                      stop = self.visit(args[0])
                 elif len(args) == 2:
                      start = self.visit(args[0])
                      stop = self.visit(args[1])

                 iter_expr = f"{start}..{stop}"
             elif node.iter.func.id == "enumerate":
                 if node.iter.args:
                     iter_expr = self.visit(node.iter.args[0])
                     # Handle target for enumerate: for i, v in items
                     if isinstance(node.target, ast.Tuple):
                         # visit_Tuple returns [i, v], we need i, v
                         if target.startswith("[") and target.endswith("]"):
                             target = target[1:-1]
                     else:
                         # Single variable target for enumerate (e.g. for x in enumerate(items))
                         self.output.append(f"{self._indent()}// TODO: handle enumerate with single target variable")

        self.output.append(f"{self._indent()}for {target} in {iter_expr} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Try(self, node: ast.Try) -> None:
        self.output.append(f"{self._indent()}// try {{")

        for stmt in node.body:
            self.visit(stmt)

        self.output.append(f"{self._indent()}// }} except {{")

        for handler in node.handlers:
            self.output.append(f"{self._indent()}// Handler: {handler.type}")
            self.output.append(f"{self._indent()}// ... exception handling logic ...")

        if node.finalbody:
             self.output.append(f"{self._indent()}// }} finally {{")
             self.output.append(f"{self._indent()}defer {{")
             self._indent_level += 1
             for stmt in node.finalbody:
                 self.visit(stmt)
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")

    def visit_With(self, node: ast.With) -> None:
        for item in node.items:
            context_expr = self.visit(item.context_expr)
            if item.optional_vars:
                var = self.visit(item.optional_vars)
                self.output.append(f"{self._indent()}{var} := {context_expr}")
                self.output.append(f"{self._indent()}defer {{ {var}.close() }}")
            else:
                self.output.append(f"{self._indent()}_ := {context_expr}")

        for stmt in node.body:
            self.visit(stmt)

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
