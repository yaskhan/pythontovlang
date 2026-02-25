import ast
from typing import List, Optional
from .base import TranslatorBase

class ExpressionsMixin(TranslatorBase):
    def visit_Expr(self, node: ast.Expr) -> None:
        val = self.visit(node.value)
        if val:
            self.output.append(f"{self._indent()}{val}")

    def visit_Call(self, node: ast.Call) -> str:
        # Check if we can resolve the call via mapper
        args = []
        for arg in node.args:
            val = self.visit(arg)
            if val is not None:
                args.append(str(val))
            else:
                args.append("/* unknown */")

        func_node = node.func
        module_name = None
        func_name = None

        # Resolve qualified name if possible (e.g. datetime.datetime.now or os.path.join)
        qualified_name_parts: List[str] = []
        curr = func_node
        while isinstance(curr, ast.Attribute):
            qualified_name_parts.insert(0, curr.attr)
            curr = curr.value

        if isinstance(curr, ast.Name):
            qualified_name_parts.insert(0, curr.id)
            # Check if root is a known module
            root_name = qualified_name_parts[0]
            if root_name in self.imported_modules:
                 module_name = self.imported_modules[root_name]
                 # construct func_name from rest
                 func_name = ".".join(qualified_name_parts[1:])
            elif root_name == "os" and len(qualified_name_parts) > 1 and qualified_name_parts[1] == "path":
                 # Special case for os.path
                 module_name = "os"
                 func_name = ".".join(qualified_name_parts[1:])

        if not module_name and isinstance(func_node, ast.Attribute):
            # obj.method() fallback
            if isinstance(func_node.value, ast.Name) and func_node.value.id in self.imported_modules:
                module_name = self.imported_modules[func_node.value.id]
                func_name = func_node.attr

        if not module_name and isinstance(func_node, ast.Name):
            # func()
            if func_node.id in self.imported_symbols:
                # from mod import func
                full_name = self.imported_symbols[func_node.id]
                parts = full_name.split(".")
                module_name = parts[0]
                func_name = parts[1]
            elif func_node.id == "open":
                module_name = "os" # synthetic
                func_name = "open"
            elif func_node.id in ("hasattr", "getattr", "setattr", "type", "super"):
                 module_name = "builtins" # synthetic
                 func_name = func_node.id

        if module_name == "os" and func_name == "open":
             # Handle open() -> os.open()
             self.emitter.add_import("os")
             if len(args) >= 1:
                 # In V: os.open(path) returns ?File, so we unwrap it.
                 # Assuming read mode for simplicity as mapped from open(path)
                 return f"os.open({args[0]}) or {{ panic(err) }}"

        if module_name == "builtins":
            if func_name == "hasattr":
                 # hasattr(obj, 'attr')
                 # Best effort: comments
                 return f"/* hasattr({', '.join(args)}) - reflection not fully supported */ false"
            elif func_name == "getattr":
                 if len(args) >= 2:
                      # check if args[1] is string literal
                      # args[1] is already visited code, e.g. "'attr'"
                      attr_name = args[1]
                      if attr_name.startswith("'") and attr_name.endswith("'"):
                           return f"{args[0]}.{attr_name[1:-1]}"
                 return f"/* getattr({', '.join(args)}) - dynamic access not supported */"
            elif func_name == "setattr":
                 if len(args) >= 3:
                      attr_name = args[1]
                      if attr_name.startswith("'") and attr_name.endswith("'"):
                           return f"{args[0]}.{attr_name[1:-1]} = {args[2]}"
                 return f"/* setattr({', '.join(args)}) - dynamic setting not supported */"
            elif func_name == "type":
                if len(args) >= 1:
                    return f"typeof({args[0]}).name"
            elif func_name == "super":
                 pass

        if module_name and func_name:
            mapped = self.mapper.get_mapping(module_name, func_name, args)
            if mapped:
                return mapped

        # Try finding os.path.X by concatenating if attribute access
        if isinstance(func_node, ast.Attribute) and isinstance(func_node.value, ast.Attribute):
             # os.path.join -> value is os.path, attr is join
             # Check if os.path is module
             pass

        # Handle threading.Lock.acquire/release -> lock/unlock
        # Heuristic: if method name is acquire/release and receiver is unknown or mapped to sync.Mutex (hard to know type here)
        # We can just map acquire->lock, release->unlock generally if threading is imported?
        # Or check if receiver name suggests lock?
        # Safe approach: if threading is used, and method is acquire/release, map it.
        # But this might conflict with other classes.
        # Let's check mapped type? We don't have robust type inference for variables yet.
        # Just map it for now if threading is imported.
        if "threading" in self.imported_modules.values() and isinstance(func_node, ast.Attribute):
             if func_node.attr == "acquire":
                 receiver = self.visit(func_node.value)
                 return f"{receiver}.lock()"
             elif func_node.attr == "release":
                 receiver = self.visit(func_node.value)
                 return f"{receiver}.unlock()"

        # Handle super().method()
        if isinstance(func_node, ast.Attribute) and isinstance(func_node.value, ast.Call) and \
           isinstance(func_node.value.func, ast.Name) and func_node.value.func.id == "super":
            # super().method(...)
            method_name = func_node.attr
            if self.current_class_bases:
                parent = self.current_class_bases[0]
                return f"self.{parent}.{method_name}({', '.join(args)})"
            else:
                 return f"/* super().{method_name} call without known parent */"

        # Handle unittest assertions
        # Strictly check for self.assertX if possible to avoid regressions
        # We check if receiver is "self"
        is_self_assertion = False
        if isinstance(func_node, ast.Attribute) and func_node.attr.startswith("assert"):
             if isinstance(func_node.value, ast.Name) and func_node.value.id == "self":
                 is_self_assertion = True

        if is_self_assertion and isinstance(func_node, ast.Attribute):
             assertion = func_node.attr
             if assertion == "assertEqual" and len(args) == 2:
                  return f"assert {args[0]} == {args[1]}"
             elif assertion == "assertNotEqual" and len(args) == 2:
                  return f"assert {args[0]} != {args[1]}"
             elif assertion == "assertTrue" and len(args) == 1:
                  return f"assert {args[0]}"
             elif assertion == "assertFalse" and len(args) == 1:
                  return f"assert !({args[0]})"
             elif assertion == "assertIn" and len(args) == 2:
                  return f"assert {args[0]} in {args[1]}"
             elif assertion == "assertNotIn" and len(args) == 2:
                  return f"assert {args[0]} !in {args[1]}"
             elif assertion == "assertIsNone" and len(args) == 1:
                  return f"assert {args[0]} == none"
             elif assertion == "assertIsNotNone" and len(args) == 1:
                  return f"assert {args[0]} != none"
             elif assertion == "assertIs" and len(args) == 2:
                   return f"assert {args[0]} == {args[1]}" # Approx
             elif assertion == "assertIsNot" and len(args) == 2:
                   return f"assert {args[0]} != {args[1]}" # Approx

        # unittest.main()
        if module_name == "unittest" and func_name == "main":
             return "// unittest.main() ignored"

        # Fallback to existing logic
        func_name_str = self.visit(node.func)
        if func_name_str in self.renamed_functions:
            func_name_str = self.renamed_functions[func_name_str]

        # Handle builtins handled by old logic (print, sorted, etc)
        # Note: 'open', 'hasattr' are handled above or fall through if not matched.
        # But wait, open is not in existing logic.

        if isinstance(func_node, ast.Attribute) and func_node.attr == "clear" and not module_name:
             obj = self.visit(func_node.value)
             return f"/* {obj}.clear() */ {obj} = {{}}"

        if func_name_str == "sorted":
            self.used_builtins.add("sorted")
            return f"py_sorted({', '.join(args)})"
        elif func_name_str == "reversed":
            self.used_builtins.add("reversed")
            return f"py_reversed({', '.join(args)})"
        elif func_name_str == "map":
            if len(args) == 2:
                func = args[0]
                iterable = args[1]
                return f"{iterable}.map({func}(it))"
        elif func_name_str == "filter":
            if len(args) == 2:
                func = args[0]
                iterable = args[1]
                if func == "None" or func == "none":
                    return f"{iterable}.filter(it)"
                return f"{iterable}.filter({func}(it))"
        elif func_name_str == "any" or func_name_str == "all":
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
                        return f"{iter_expr}.{func_name_str}({elt})"
                else:
                    # any(iterable) -> iterable.any(it)
                    val = self.visit(arg)
                    return f"{val}.{func_name_str}(it)"

        elif func_name_str == "isinstance":
            if len(args) == 2:
                obj = args[0]
                types = args[1]
                if types.startswith("[") and types.endswith("]"):
                     return f"/* isinstance({obj}, {types}) - multi-type check not supported */ false"
                return f"{obj} is {types}"

        elif func_name_str == "input":
            self.emitter.add_import("os")
            if args:
                return f"os.input({args[0]})"
            return "os.input('')"

        elif func_name_str == "print":
            sep = " "
            end = "\\n"

            for keyword in node.keywords:
                if keyword.arg == "sep":
                    if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                        sep = keyword.value.value
                elif keyword.arg == "end":
                    if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                        end = keyword.value.value
                        if end == "\n":
                            end = "\\n"

            parts = []
            for arg in node.args:
                val = self.visit(arg)
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

        return f"{func_name_str}({', '.join(args)})"

    def visit_Attribute(self, node: ast.Attribute) -> str:
        # Check if this is a mapped constant (e.g. math.pi)
        if isinstance(node.value, ast.Name) and node.value.id in self.imported_modules:
             module_name = self.imported_modules[node.value.id]
             const_name = node.attr
             mapped = self.mapper.get_constant_mapping(module_name, const_name)
             if mapped:
                 return mapped

        if node.attr == "__class__":
             obj = self.visit(node.value)
             return f"typeof({obj})"

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

    def visit_BinOp(self, node: ast.BinOp) -> str:
        left = self.visit(node.left)
        right = self.visit(node.right)
        op_map = {
            ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/",
            ast.Mod: "%", ast.Pow: "**"
        }
        op_str = op_map.get(type(node.op), "?")
        return f"{left} {op_str} {right}"

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

    def visit_Compare(self, node: ast.Compare) -> str:
        comparators = [self.visit(node.left)] + [self.visit(c) for c in node.comparators]
        ops_map = {
            ast.Eq: "==", ast.NotEq: "!=", ast.Lt: "<", ast.LtE: "<=",
            ast.Gt: ">", ast.GtE: ">=", ast.Is: "==", ast.IsNot: "!=",
            ast.In: "in", ast.NotIn: "!in"
        }

        if len(node.ops) == 1:
            left = comparators[0]
            right = comparators[1]
            op = node.ops[0]
            op_str = ops_map.get(type(op), "?")

            if isinstance(op, ast.Is) and str(right) == "none":
                 op_str = "=="
            elif isinstance(op, ast.IsNot) and str(right) == "none":
                 op_str = "!="

            return f"{left} {op_str} {right}"

        parts = []
        for i, op in enumerate(node.ops):
            left = comparators[i]
            right = comparators[i+1]
            op_str = ops_map.get(type(op), "?")

            if isinstance(op, ast.Is) and str(right) == "none":
                 op_str = "=="
            elif isinstance(op, ast.IsNot) and str(right) == "none":
                 op_str = "!="

            parts.append(f"({left} {op_str} {right})")

        return " && ".join(parts)

    def visit_ListComp(self, node: ast.ListComp, target_var: Optional[str] = None) -> None:
        if not target_var:
            self.output.append(f"{self._indent()}// List comprehension expression not supported inline yet")
            return

        self.output.append(f"{self._indent()}mut {target_var} := []int{{}}")

        gen = node.generators[0] # Handle first generator

        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name) and gen.iter.func.id == "zip":
             zip_args = gen.iter.args
             if len(zip_args) == 2:
                 self._zip_counter += 1
                 zip_id = self._zip_counter

                 it1 = self.visit(zip_args[0])
                 it2 = self.visit(zip_args[1])

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
                 range_args = gen.iter.args
                 if len(range_args) == 3:
                     # range(start, stop, step) -> C-style for loop
                     # We need to manually construct the loop here because `visit_ListComp` expects `iter_expr`
                     # But `iter_expr` is usually an iterable.
                     # However, `visit_ListComp` uses `for {target} in {iter_expr} {`.
                     # We can trick it by setting iter_expr to handle the step? No, `in` syntax doesn't support step.
                     # We must emit a C-style loop: `for i := start; i < stop; i += step {`
                     # But `visit_ListComp` hardcodes `for ... in ...`.
                     # We need to restructure `visit_ListComp` to handle this or modify the output manually.
                     # Let's override the loop generation for range with step.

                     start = self.visit(range_args[0])
                     stop = self.visit(range_args[1])
                     step = self.visit(range_args[2])

                     is_negative_step = False
                     if isinstance(range_args[2], ast.UnaryOp) and isinstance(range_args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(range_args[2], ast.Constant) and isinstance(range_args[2].value, (int, float)) and range_args[2].value < 0:
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
                 if len(range_args) == 1:
                      stop = self.visit(range_args[0])
                 elif len(range_args) == 2:
                      start = self.visit(range_args[0])
                      stop = self.visit(range_args[1])
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

    def visit_DictComp(self, node: ast.DictComp, target_var: Optional[str] = None) -> None:
        if not target_var:
            self.output.append(f"{self._indent()}// Dict comprehension expression not supported inline yet")
            return

        gen = node.generators[0] # Handle first generator
        self._infer_generator_types(gen)

        key_type = self._guess_type(node.key)
        val_type = self._guess_type(node.value)
        self.output.append(f"{self._indent()}mut {target_var} := map[{key_type}]{val_type}{{}}")

        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name) and gen.iter.func.id == "zip":
             zip_args = gen.iter.args
             if len(zip_args) == 2:
                 self._zip_counter += 1
                 zip_id = self._zip_counter

                 it1 = self.visit(zip_args[0])
                 it2 = self.visit(zip_args[1])

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

                 key = self.visit(node.key)
                 val = self.visit(node.value)
                 self.output.append(f"{self._indent()}{target_var}[{key}] = {val}")

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
                 range_args = gen.iter.args
                 if len(range_args) == 3:
                     # range(start, stop, step) -> C-style for loop
                     start = self.visit(range_args[0])
                     stop = self.visit(range_args[1])
                     step = self.visit(range_args[2])

                     is_negative_step = False
                     if isinstance(range_args[2], ast.UnaryOp) and isinstance(range_args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(range_args[2], ast.Constant) and isinstance(range_args[2].value, (int, float)) and range_args[2].value < 0:
                         is_negative_step = True

                     op = ">" if is_negative_step else "<"

                     self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
                     self._indent_level += 1

                     for if_expr in gen.ifs:
                        cond = self.visit(if_expr)
                        self.output.append(f"{self._indent()}if {cond} {{")
                        self._indent_level += 1

                     key = self.visit(node.key)
                     val = self.visit(node.value)
                     self.output.append(f"{self._indent()}{target_var}[{key}] = {val}")

                     for _ in gen.ifs:
                        self._indent_level -= 1
                        self.output.append(f"{self._indent()}}}")

                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")
                     return

                 start = "0"
                 stop = "0"
                 if len(range_args) == 1:
                      stop = self.visit(range_args[0])
                 elif len(range_args) == 2:
                      start = self.visit(range_args[0])
                      stop = self.visit(range_args[1])
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

        key = self.visit(node.key)
        val = self.visit(node.value)
        self.output.append(f"{self._indent()}{target_var}[{key}] = {val}")

        for _ in gen.ifs:
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def _guess_type(self, node: ast.AST) -> str:
        if isinstance(node, ast.Constant):
             if isinstance(node.value, int): return "int"
             if isinstance(node.value, float): return "f64"
             if isinstance(node.value, str): return "string"
             if isinstance(node.value, bool): return "bool"
             return "int"
        elif isinstance(node, ast.Name):
            # Try to resolve via type inference
            inferred = self.type_inference.resolve_type(node)
            if inferred != "void":
                return inferred
            return "int" # Fallback
        elif isinstance(node, ast.BinOp):
            if isinstance(node.op, ast.Div):
                return "f64"
            # For Add/Sub/Mult/Mod/Pow, check operands
            left = self._guess_type(node.left)
            right = self._guess_type(node.right)
            if left == "f64" or right == "f64": return "f64"
            if left == "string" or right == "string": return "string"
            return "int"
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                fid = node.func.id
                if fid == "str": return "string"
                if fid == "int": return "int"
                if fid == "float": return "f64"
                if fid == "bool": return "bool"
                if fid == "len": return "int"

        return "int"

    def _infer_generator_types(self, gen: ast.comprehension) -> None:
        """Infers types of loop variables from the generator and updates type_map."""
        iter_node = gen.iter
        target_node = gen.target

        # Handle simple range
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "range":
            if isinstance(target_node, ast.Name):
                self.type_inference.type_map[target_node.id] = "int"

        # Handle list literal
        elif isinstance(iter_node, ast.List):
            if iter_node.elts:
                elt_type = self._guess_type(iter_node.elts[0])
                if isinstance(target_node, ast.Name):
                    self.type_inference.type_map[target_node.id] = elt_type

        # Handle zip
        elif isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "zip":
            if isinstance(target_node, ast.Tuple):
                for i, arg in enumerate(iter_node.args):
                    if i < len(target_node.elts):
                        t_elt = target_node.elts[i]
                        if isinstance(t_elt, ast.Name):
                            # Guess type of the argument (list literal, etc)
                            if isinstance(arg, ast.List) and arg.elts:
                                arg_type = self._guess_type(arg.elts[0])
                                self.type_inference.type_map[t_elt.id] = arg_type
                            elif isinstance(arg, ast.Call) and isinstance(arg.func, ast.Name) and arg.func.id == "range":
                                self.type_inference.type_map[t_elt.id] = "int"

    def visit_SetComp(self, node: ast.SetComp, target_var: Optional[str] = None) -> None:
        if not target_var:
            self.output.append(f"{self._indent()}// Set comprehension expression not supported inline yet")
            return

        gen = node.generators[0] # Handle first generator
        self._infer_generator_types(gen)

        key_type = self._guess_type(node.elt)
        self.output.append(f"{self._indent()}mut {target_var} := map[{key_type}]bool{{}}")

        if isinstance(gen.iter, ast.Call) and isinstance(gen.iter.func, ast.Name) and gen.iter.func.id == "zip":
             zip_args = gen.iter.args
             if len(zip_args) == 2:
                 self._zip_counter += 1
                 zip_id = self._zip_counter

                 it1 = self.visit(zip_args[0])
                 it2 = self.visit(zip_args[1])

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
                 self.output.append(f"{self._indent()}{target_var}[{elt}] = true")

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
                 range_args = gen.iter.args
                 if len(range_args) == 3:
                     # range(start, stop, step) -> C-style for loop
                     start = self.visit(range_args[0])
                     stop = self.visit(range_args[1])
                     step = self.visit(range_args[2])

                     is_negative_step = False
                     if isinstance(range_args[2], ast.UnaryOp) and isinstance(range_args[2].op, ast.USub):
                         is_negative_step = True
                     elif isinstance(range_args[2], ast.Constant) and isinstance(range_args[2].value, (int, float)) and range_args[2].value < 0:
                         is_negative_step = True

                     op = ">" if is_negative_step else "<"

                     self.output.append(f"{self._indent()}for {target} := {start}; {target} {op} {stop}; {target} += {step} {{")
                     self._indent_level += 1

                     for if_expr in gen.ifs:
                        cond = self.visit(if_expr)
                        self.output.append(f"{self._indent()}if {cond} {{")
                        self._indent_level += 1

                     elt = self.visit(node.elt)
                     self.output.append(f"{self._indent()}{target_var}[{elt}] = true")

                     for _ in gen.ifs:
                        self._indent_level -= 1
                        self.output.append(f"{self._indent()}}}")

                     self._indent_level -= 1
                     self.output.append(f"{self._indent()}}}")
                     return

                 start = "0"
                 stop = "0"
                 if len(range_args) == 1:
                      stop = self.visit(range_args[0])
                 elif len(range_args) == 2:
                      start = self.visit(range_args[0])
                      stop = self.visit(range_args[1])
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
        self.output.append(f"{self._indent()}{target_var}[{elt}] = true")

        for _ in gen.ifs:
            self._indent_level -= 1
            self.output.append(f"{self._indent()}}}")

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

    def visit_Assert(self, node: ast.Assert) -> None:
        test = self.visit(node.test)
        self.output.append(f"{self._indent()}assert {test}")
