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

    def _indent(self) -> str:
        return "    " * self._indent_level

    def visit_Module(self, node: ast.Module) -> str:
        for stmt in node.body:
            # Check if statement is top-level expression or assignment
            if isinstance(stmt, (ast.FunctionDef, ast.ClassDef, ast.Import, ast.ImportFrom)):
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
            if isinstance(stmt, ast.FunctionDef):
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
            # Map Python module to V module
            # Ideally use a mapper function, but 1:1 for now
            self.emitter.add_import(alias.name)

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        if node.module:
            self.emitter.add_import(node.module)
        # We don't support explicit name imports (from x import y) fully in V structure yet
        # V usually imports the whole module.

    def visit_Assign(self, node: ast.Assign) -> None:
        target = node.targets[0]
        lhs = ""
        if isinstance(target, ast.Name):
            lhs = target.id
        elif isinstance(target, ast.Attribute):
            # obj.attr = value
            lhs = f"{self.visit(target.value)}.{target.attr}"

        if isinstance(node.value, ast.ListComp):
            # Special handling for list comprehension in assignment
            # x = [i for i in iter]
            # -> mut x := []int{}
            #    for i in iter { x << i }

            # This is tricky because we need to know the type of list elements.
            # Assuming int for now or inferring later.

            # We emit the block directly
            self.visit_ListComp(node.value, target_var=lhs)
        else:
            rhs = self.visit(node.value)
            self.output.append(f"{self._indent()}{lhs} := {rhs}")

    def visit_ListComp(self, node: ast.ListComp, target_var: Optional[str] = None) -> None:
        if not target_var:
            # If not part of assignment, we can't easily translate to statements.
            self.output.append(f"{self._indent()}// List comprehension expression not supported inline yet")
            return

        # Initialize result array
        # Assuming []int for now, ideally inference
        self.output.append(f"{self._indent()}mut {target_var} := []int{{}}")

        # Handle generators
        # Python: [elt for target in iter if ifs]
        # V: for target in iter { if ifs { acc << elt } }

        gen = node.generators[0] # Handle first generator
        target = self.visit(gen.target)
        iter_expr = self.visit(gen.iter)

        # Expand range() if needed (same logic as visit_For)
        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name) and gen.iter.func.id == "range":
             args = gen.iter.args
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

        # Conditions
        for if_expr in gen.ifs:
            cond = self.visit(if_expr)
            self.output.append(f"{self._indent()}if {cond} {{")
            self._indent_level += 1

        # Append element
        elt = self.visit(node.elt)
        self.output.append(f"{self._indent()}{target_var} << {elt}")

        # Close blocks
        for _ in gen.ifs:
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Dict(self, node: ast.Dict) -> str:
        # Translate {k: v} to map[string]int{k: v} (simplified type)
        pairs = []
        for k, v in zip(node.keys, node.values):
            if k:
                key_str = self.visit(k)
                val_str = self.visit(v)
                pairs.append(f"{key_str}: {val_str}")

        # TODO: infer type
        return f"map[string]int{{{', '.join(pairs)}}}"

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
        # Handle instantiation: ClassName(...) -> new_ClassName(...)?
        # Or just ClassName{...} struct init syntax?
        # Python: x = MyClass() -> x := MyClass{} or x := new_MyClass()

        func_name = self.visit(node.func)

        # Heuristic: if func_name starts with capital letter, assume struct init
        # V struct init: StructName{} (if no args) or StructName{field: val}
        # But we defined __init__ as new_StructName factory.

        # Let's assume we use the factory if it exists, or struct init if not.
        # But we don't know if __init__ exists here easily.
        # Let's verify if the name matches a known struct?
        # For now, just generate the call.

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
