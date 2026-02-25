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
        self.used_builtins = set() # Track used built-in helpers (sorted, reversed, etc)
        self.renamed_functions = {"main": "py_main"} # Map to rename functions (e.g. main -> py_main)
        self.name_remap = {} # Temporary variable renaming (e.g. x -> it in generators)

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

        if "sorted" in self.used_builtins:
            self.emitter.add_function(
                "fn py_sorted[T](a []T) []T {\n    mut b := a.clone()\n    b.sort()\n    return b\n}"
            )
        if "reversed" in self.used_builtins:
            self.emitter.add_function(
                "fn py_reversed[T](a []T) []T {\n    mut b := a.clone()\n    b.reverse()\n    return b\n}"
            )

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

        # Handle decorators
        for decorator in node.decorator_list:
            dec_str = self.visit(decorator)
            self.output.append(f"// @{dec_str}")

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
        if func_name in self.renamed_functions:
            func_name = self.renamed_functions[func_name]

        if func_name == "__init__":
            # Constructor logic: make it a static factory function for now
            # fn new_Struct(...) Struct
            func_name = f"new_{struct_name}"
            receiver_str = "" # Factory is static
            ret_type = struct_name
            # We need to implicitly return the struct instance, but that's complex logic.
            # For now, just change the name.
        elif is_method and func_name in ("__add__", "__sub__", "__mul__", "__truediv__", "__mod__", "__lt__", "__le__", "__eq__", "__ne__"):
             # Operator overloading
             # fn (a Type) + (b Type) Type
             op_map = {
                 "__add__": "+", "__sub__": "-", "__mul__": "*", "__truediv__": "/",
                 "__mod__": "%", "__lt__": "<", "__le__": "<=", "__eq__": "==",
                 "__ne__": "!="
             }
             op = op_map.get(func_name)
             if op:
                 func_name = op
                 # In V, operator overloading syntax is: fn (a Type) + (b Type) RetType
                 # Our args_str is "b Type". We need to format it as "(b Type)".
                 # receiver_str is "(a Type) ".
                 # So: fn (a Type) + (b Type) RetType
                 # We need to ensure args_str is wrapped in parens if not already (it isn't, it's a comma list)
                 decl = f"fn {receiver_str}{op} ({args_str}) {ret_type} {{"
                 # Skip the default decl assignment below
        elif func_name == "__str__":
             # String representation
             func_name = "str"
             decl = f"fn {receiver_str}{func_name}() string {{"

        if 'decl' not in locals():
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

        # Handle decorators
        decorators = []
        for decorator in node.decorator_list:
            dec_str = self.visit(decorator)
            decorators.append(f"// @{dec_str}")

        # Extract fields from __init__ or class body annotations (simplified)
        fields = []

        # Handle inheritance (bases)
        for base in node.bases:
            if isinstance(base, ast.Name):
                fields.append(f"    {base.id}")
            # Could handle Attribute (e.g. module.Class) too
            elif isinstance(base, ast.Attribute):
                fields.append(f"    {self.visit(base)}")

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

        struct_def = ""
        if decorators:
            struct_def += "\n".join(decorators) + "\n"
        struct_def += f"struct {struct_name} {{\n" + "\n".join(fields) + "\n}"
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
            # Check for type alias: MyType = int
            if self.in_main and isinstance(node.value, ast.Name) and node.value.id in ("int", "str", "bool", "float"):
                self.output.append(f"type {lhs} = {node.value.id}")
                return
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
                 if len(args) == 3:
                     # range(start, stop, step) -> C-style for loop
                     # We need to manually construct the loop here because `visit_ListComp` expects `iter_expr`
                     # But `iter_expr` is usually an iterable.
                     # However, `visit_ListComp` uses `for {target} in {iter_expr} {`.
                     # We can trick it by setting iter_expr to handle the step? No, `in` syntax doesn't support step.
                     # We must emit a C-style loop: `for i := start; i < stop; i += step {`
                     # But `visit_ListComp` hardcodes `for ... in ...`.
                     # We need to restructure `visit_ListComp` to handle this or modify the output manually.
                     # Let's override the loop generation for range with step.

                     start = self.visit(args[0])
                     stop = self.visit(args[1])
                     step = self.visit(args[2])

                     is_negative_step = False
                     if isinstance(args[2], ast.UnaryOp) and isinstance(args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(args[2], ast.Constant) and isinstance(args[2].value, (int, float)) and args[2].value < 0:
                         is_negative_step = True

                     op = ">" if is_negative_step else "<"

                     # We skip the standard `visit_ListComp` loop generation logic for this specific generator
                     # and manually implement it.

                     self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
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
                     return

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

    def visit_Delete(self, node: ast.Delete) -> None:
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                # del l[i] -> l.delete(i)
                value = self.visit(target.value)
                index = self.visit(target.slice)
                self.output.append(f"{self._indent()}{value}.delete({index})")
            elif isinstance(target, ast.Name):
                self.output.append(f"{self._indent()}// del {target.id} (variable deletion not supported in V)")
            elif isinstance(target, ast.Attribute):
                value = self.visit(target.value)
                self.output.append(f"{self._indent()}// del {value}.{target.attr} (attribute deletion not supported)")
            else:
                self.output.append(f"{self._indent()}// del statement with unsupported target type")

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
        if func_name in self.renamed_functions:
            func_name = self.renamed_functions[func_name]

        args = []
        for arg in node.args:
            val = self.visit(arg)
            if val is not None:
                args.append(str(val))
            else:
                args.append("/* unknown */")

        if func_name == "sorted":
            self.used_builtins.add("sorted")
            return f"py_sorted({', '.join(args)})"
        elif func_name == "reversed":
            self.used_builtins.add("reversed")
            return f"py_reversed({', '.join(args)})"
        elif func_name == "map":
            if len(args) == 2:
                func = args[0]
                iterable = args[1]
                return f"{iterable}.map({func}(it))"
        elif func_name == "filter":
            if len(args) == 2:
                func = args[0]
                iterable = args[1]
                if func == "None" or func == "none":
                    return f"{iterable}.filter(it)"
                return f"{iterable}.filter({func}(it))"
        elif func_name == "any" or func_name == "all":
            if len(node.args) == 1:
                arg = node.args[0]
                if isinstance(arg, ast.GeneratorExp):
                    # any(expr for target in iter) -> iter.any(expr_with_it)
                    gen = arg.generators[0]
                    target = gen.target
                    iter_expr = self.visit(gen.iter)

                    if isinstance(target, ast.Name):
                        # Map target name to 'it'
                        self.name_remap[target.id] = "it"
                        elt = self.visit(arg.elt)
                        del self.name_remap[target.id]
                        return f"{iter_expr}.{func_name}({elt})"
                else:
                    # any(iterable) -> iterable.any(it)
                    val = self.visit(arg)
                    return f"{val}.{func_name}(it)"

        elif func_name == "isinstance":
            if len(args) == 2:
                obj = args[0]
                types = args[1]
                # Check if it's a single type check: isinstance(x, MyClass) -> x is MyClass
                # If types is a tuple (array in V representation), it's harder.
                # args[1] string comes from self.visit(), so it might be "MyClass" or "[int, float]"
                if types.startswith("[") and types.endswith("]"):
                     # Multiple types check not directly supported in 'is' expression
                     return f"/* isinstance({obj}, {types}) - multi-type check not supported */ false"
                return f"{obj} is {types}"

        elif func_name == "input":
            self.emitter.add_import("os")
            if args:
                return f"os.input({args[0]})"
            return "os.input('')"

        elif func_name == "print":
            sep = " "
            end = "\\n"

            for keyword in node.keywords:
                if keyword.arg == "sep":
                    if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                        sep = keyword.value.value
                elif keyword.arg == "end":
                    if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                        end = keyword.value.value
                        # Escape newline for V string if literal newline
                        if end == "\n":
                            end = "\\n"

            # Construct the content string
            # In V, interpolation handles types: '${var}'
            # We want to join args with sep.
            # If args are strings, we can just join them.
            # If args are vars, we wrap in ${}.
            # Simplified: always wrap in ${} unless it's a string literal?
            # Actually, `visit` returns the V representation (e.g. 'foo' or var).

            parts = []
            for arg in node.args:
                val = self.visit(arg)
                # Strip quotes if it's a string literal to merge into one string?
                # E.g. 'A', 'B' -> 'A B'
                # val is like "'A'" or "x"
                val_str = str(val)
                if val_str.startswith("'") and val_str.endswith("'"):
                    parts.append(val_str[1:-1])
                else:
                    parts.append(f"${{{val_str}}}")

            joined_content = sep.join(parts)

            if end == "\\n":
                return f"println('{joined_content}')"
            elif end == "":
                return f"print('{joined_content}')"
            else:
                return f"print('{joined_content}{end}')"

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
        # Check for if __name__ == "__main__":
        if isinstance(node.test, ast.Compare):
            if (isinstance(node.test.left, ast.Name) and node.test.left.id == "__name__" and
                len(node.test.comparators) == 1 and isinstance(node.test.comparators[0], ast.Constant) and
                node.test.comparators[0].value == "__main__"):
                self.output.append(f"{self._indent()}// if __name__ == '__main__':")
                for stmt in node.body:
                    self.visit(stmt)
                return

        # Check for walrus operator in condition: if (x := expr):
        walrus_assignment = None
        if isinstance(node.test, ast.NamedExpr):
             # Extract the assignment
             target = node.test.target.id
             value = self.visit(node.test.value)
             walrus_assignment = f"{target} := {value}"
             # The condition becomes just the target (if boolean check) or the value?
             # Actually, (x := 5) returns 5.
             # So if (x := 5) > 0 becomes: x := 5; if x > 0 {
             # But here node.test IS the named expr.
             # If it's part of a larger expression (e.g. Compare), we need to traverse finding NamedExpr.
             # Doing full traversal is hard. Let's support the simple case where NamedExpr is the test or part of it?
             # Actually, visit_NamedExpr will be called if we just visit(node.test).
             # We need visit_NamedExpr to return the value (for the expression) but ALSO emit the assignment BEFORE.
             # But we can't emit before easily inside an expression.
             # Strategy: Detect NamedExpr at the top level of the condition or handle it specifically.
             pass

        # New strategy for Walrus:
        # 1. Pre-visit the test expression to find NamedExprs.
        # 2. Emit their assignments.
        # 3. Replace NamedExpr in the test with just the target variable.
        # This is complex to do without mutating the AST or complex visitor.
        # Simplified: If the test contains a NamedExpr, we extract it.

        # Let's try to handle NamedExpr via a specific helper or just handle the top-level case first?
        # In `if (x := 5) > 0`: the test is Compare(left=NamedExpr(...), ops=..., comparators=...)

        # We will implement `visit_NamedExpr` to return the target name, and SIDE-EFFECT emit the assignment?
        # But if we emit inside `if ... {`, it breaks syntax.
        # So we must emit BEFORE the `if`.

        # Let's peek for NamedExpr
        self._walrus_assignments = []
        test_expr = self.visit(node.test)

        if hasattr(self, '_walrus_assignments') and self._walrus_assignments:
             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")
             self._walrus_assignments = []

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
        # Check for walrus in while: while (x := expr):
        # Vlang doesn't support this.
        # Transform to: for { x := expr; if !cond { break } ... }

        # We need to detect if there is a walrus operator.
        # Similar to If, we can capture it.

        self._walrus_assignments = []
        # We need to buffer the output because visiting test might emit things (if we implemented it that way, but we didn't yet)
        # But wait, `visit_NamedExpr` needs to be implemented.

        # We can't easily execute visit(node.test) twice or speculatively.
        # But we can assume visit_NamedExpr will populate _walrus_assignments.

        test_expr = self.visit(node.test)

        if hasattr(self, '_walrus_assignments') and self._walrus_assignments:
             # Found walrus! Transform loop.
             self.output.append(f"{self._indent()}for {{")
             self._indent_level += 1

             for assign in self._walrus_assignments:
                 self.output.append(f"{self._indent()}{assign}")

             self.output.append(f"{self._indent()}if !({test_expr}) {{ break }}")
             self._walrus_assignments = []

             for stmt in node.body:
                 self.visit(stmt)

             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")
        else:
             # Normal while
             self.output.append(f"{self._indent()}for {test_expr} {{")
             self._indent_level += 1
             for stmt in node.body:
                 self.visit(stmt)
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")

    def visit_NamedExpr(self, node: ast.NamedExpr) -> str:
        # (target := value)
        target = node.target.id
        value = self.visit(node.value)

        # We need to register this assignment to be emitted before the statement
        if not hasattr(self, '_walrus_assignments'):
            self._walrus_assignments = []

        self._walrus_assignments.append(f"{target} := {value}")

        return target

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
                 if len(args) == 3:
                     # range(start, stop, step) -> C-style for loop
                     start = self.visit(args[0])
                     stop = self.visit(args[1])
                     step = self.visit(args[2])

                     is_negative_step = False
                     if isinstance(args[2], ast.UnaryOp) and isinstance(args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(args[2], ast.Constant) and isinstance(args[2].value, (int, float)) and args[2].value < 0:
                         is_negative_step = True

                     op = ">" if is_negative_step else "<"

                     self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
                     self._indent_level += 1
                     for stmt in node.body:
                         self.visit(stmt)
                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")
                     return

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
        if node.id in self.name_remap:
            return self.name_remap[node.id]
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

    def visit_Match(self, node: ast.Match) -> None:
        subject = self.visit(node.subject)
        self.output.append(f"{self._indent()}match {subject} {{")
        self._indent_level += 1

        for case in node.cases:
            self._visit_match_case(case)

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def _visit_match_case(self, node: ast.match_case) -> None:
        pattern_str = self._translate_pattern(node.pattern)

        if node.guard:
            self.output.append(f"{self._indent()}// Guard condition '{self.visit(node.guard)}' ignored in match case")

        self.output.append(f"{self._indent()}{pattern_str} {{")
        self._indent_level += 1
        for stmt in node.body:
            self.visit(stmt)
        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def _translate_pattern(self, pattern: ast.AST) -> str:
        if isinstance(pattern, ast.MatchValue):
            return str(self.visit(pattern.value))
        elif isinstance(pattern, ast.MatchSingleton):
            return str(pattern.value).lower()
        elif isinstance(pattern, ast.MatchOr):
            parts = [self._translate_pattern(p) for p in pattern.patterns]
            return ", ".join(parts)
        elif isinstance(pattern, ast.MatchAs):
             if pattern.name is None:
                 return "else"
             else:
                 return "else" # TODO: Binding
        return "else"

    def generic_visit(self, node: ast.AST) -> Any:
        return super().generic_visit(node)
