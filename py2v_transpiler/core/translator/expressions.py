import ast
from typing import List, Optional
from .base import TranslatorBase

class ExpressionsMixin(TranslatorBase):
    def visit_Expr(self, node: ast.Expr) -> None:
        val = self.visit(node.value)
        if val:
            self.output.append(f"{self._indent()}{val}")

    def visit_Starred(self, node: ast.Starred) -> str:
        val = self.visit(node.value)
        return f"...{val}"

    def visit_Call(self, node: ast.Call) -> str:
        # Check if we can resolve the call via mapper
        args = []
        for arg in node.args:
            val = self.visit(arg)
            if val is not None:
                args.append(str(val))
            else:
                args.append("/* unknown */")

        for keyword in node.keywords:
            if keyword.arg is None:
                # **kwargs call -> pass dict as arg
                val = self.visit(keyword.value)
                args.append(str(val))

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
            # Check if any prefix is a known module (longest match first)
            for i in range(len(qualified_name_parts), 0, -1):
                prefix = ".".join(qualified_name_parts[:i])
                if prefix in self.imported_modules:
                    module_name = self.imported_modules[prefix]
                    func_name = ".".join(qualified_name_parts[i:])
                    break

            if not module_name:
                root_name = qualified_name_parts[0]
                if root_name == "os" and len(qualified_name_parts) > 1 and qualified_name_parts[1] == "path":
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

        # Handle functools.partial
        if module_name == "functools" and func_name == "partial":
             if len(args) >= 2:
                 # partial(func, *args) -> fn [func, args] (extra_args ...any) { return func(args..., extra_args...) }
                 # Simplified closure generation
                 target_func = args[0]
                 partial_args = args[1:]

                 # V anonymous function with closure capture [target_func, partial_args]
                 # Note: capturing list of strings (args) works in V if variables are defined.
                 # But args here are strings from visit(), so they are expressions.
                 # We need to capture the VALUES.
                 # This is complex to inline perfectly.
                 # Let's generate a wrapper closure.
                 # Assuming simple case: partial(add, 5)

                 # We need to generate names for arguments to capture?
                 # Or just embed expressions if they are constants/vars.
                 # `fn [target_func, partial_args] (rest ...any) { return target_func(partial_args..., rest...) }`

                 # Construct capture list string
                 # We assume args are valid expressions.
                 # But V closure capture requires variables.
                 # If partial_args contains literals, we can't capture them directly in `[]`.
                 # But we can use them directly in body if they are literals.
                 # Only variables need capturing.

                 # Heuristic: Scan partial_args for identifiers.
                 # For now, simplistic approach:
                 # fn (rest ...int) int { return target_func(partial_args, rest...) }

                 # We don't know the types!
                 # V requires types for anonymous function arguments.
                 # `fn (x int)` etc.
                 # This makes generalized partial very hard without generic lambdas (which V has limitations on).
                 # Fallback: Emit a comment and a best-effort lambda assuming 'int' or 'any' if possible.

                 # Try to deduce type from target_func? Hard.

                 # Let's emit a closure that takes `...int` and returns `int` as a common case,
                 # or `...any` if we had `any` support everywhere.

                 joined_partial = ", ".join(partial_args)
                 return f"fn (rest ...int) int {{ return {target_func}({joined_partial}, ...rest) }}"

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

        # Handle dataclass constructor call
        if hasattr(self, 'dataclasses') and func_name_str in self.dataclasses:
            field_order = self.dataclasses[func_name_str]
            struct_args = []
            # Map positional args
            for i, arg_val in enumerate(args):
                if i < len(field_order):
                    struct_args.append(f"{field_order[i]}: {arg_val}")
            # Map keyword args
            for keyword in node.keywords:
                if keyword.arg:
                     kw_val_str = str(self.visit(keyword.value))
                     struct_args.append(f"{keyword.arg}: {kw_val_str}")

            return f"{func_name_str}{{{', '.join(struct_args)}}}"

        # Handle builtins handled by old logic (print, sorted, etc)
        # Note: 'open', 'hasattr' are handled above or fall through if not matched.
        # But wait, open is not in existing logic.

        # Handle next(gen) -> gen.next()
        if func_name_str == "next" and len(args) >= 1:
             gen = args[0]
             return f"{gen}.next()"

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
                    comp_gen = arg.generators[0]
                    target = comp_gen.target
                    iter_expr = self.visit(comp_gen.iter)

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

        # Check if it is a generator call
        if self.coroutine_handler.is_generator(func_name_str):
             # Generate unique names
             ch_out_name = self.coroutine_handler.get_temp_channel_name()
             ch_in_name = ch_out_name.replace("ch_", "ch_in_")
             gen_var_name = ch_out_name.replace("ch_", "gen_")

             yield_type = self.coroutine_handler.get_generator_type(func_name_str)

             # Emit setup code
             # We must be careful about where we emit this.
             # visit_Call is expression visitor, but we are emitting statements.
             # self.output appends to current block.
             # This works if visit_Call is called at statement level (Expr).
             # If called inside expression (e.g. x = gen()), emitting statements before x = ... works in V?
             # V allows `x := { stmts; val }` block expressions but syntax is specific (unsafe block or similar).
             # Standard V does not support arbitrary statement blocks in expressions.
             # However, our TranslatorBase usually visits statements.
             # If we are inside `visit_Assign`, `visit(value)` is called.
             # If we emit statements here, they appear BEFORE the assignment statement in `self.output`.
             # So:
             # ch := ...
             # gen := ...
             # spawn ...
             # x := gen
             # This order is CORRECT for V.

             self.output.append(f"{self._indent()}{ch_out_name} := chan ?{yield_type}{{cap: 0}}")
             self.output.append(f"{self._indent()}{ch_in_name} := chan PyGeneratorInput{{cap: 0}}")
             self.output.append(f"{self._indent()}{gen_var_name} := PyGenerator[{yield_type}]{{out: {ch_out_name}, in_: {ch_in_name}}}")

             # Construct spawn arguments
             spawn_args = [ch_out_name, ch_in_name] + args
             self.output.append(f"{self._indent()}spawn {func_name_str}({', '.join(spawn_args)})")

             return gen_var_name

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

        if node.attr == "real":
             if self._guess_type(node.value) == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.re"
        elif node.attr == "imag":
             if self._guess_type(node.value) == "PyComplex":
                 obj = self.visit(node.value)
                 return f"{obj}.im"

        obj = self.visit(node.value)

        # Mangling for self.__private attributes
        # We need to know if we are accessing self inside a class
        attr_name = node.attr
        if self.current_class and isinstance(node.value, ast.Name):
            # Checking if the receiver is 'self' is tricky because 'self' is not guaranteed name.
            # But usually it is the first arg.
            # We don't easily track variable origin here.
            # However, standard Python mangling applies to ANY attribute access inside the class method
            # if the attribute starts with __
            # Wait, python mangles `self.__x` but also `other.__x` if inside Class.
            # So we apply mangling regardless of receiver, if we are inside a class.
            attr_name = self._mangle_name(node.attr, self.current_class)

        # Check if obj corresponds to a known function (Function Attributes)
        # obj is already visited code, e.g. "func_name".
        # We check if `obj` is in `self.function_names`.
        # Note: obj might be scoped (e.g. mod.func). We only track simple names for now.
        if obj in self.function_names:
            # Map func.attr -> func__attr
            return f"{obj}__{attr_name}"

        return f"{obj}.{attr_name}"

    def visit_Subscript(self, node: ast.Subscript) -> str:
        value = self.visit(node.value)

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

        if isinstance(node.slice, ast.Slice):
            lower = self.visit(node.slice.lower) if node.slice.lower else ""
            upper = self.visit(node.slice.upper) if node.slice.upper else ""
            return f"{value}[{lower}..{upper}]"
        else:
            index = self.visit(node.slice)
            return f"{value}[{index}]"

    def visit_BinOp(self, node: ast.BinOp) -> str:
        left_type = self._guess_type(node.left)
        right_type = self._guess_type(node.right)

        left = self.visit(node.left)
        right = self.visit(node.right)

        if left_type == "PyComplex" and right_type != "PyComplex":
             right = f"py_complex(f64({right}), 0.0)"
        elif right_type == "PyComplex" and left_type != "PyComplex":
             left = f"py_complex(f64({left}), 0.0)"

        if isinstance(node.op, ast.MatMult):
             return f"{left}.matmul({right})"

        # Check for bytes formatting: b"%s" % b"a"
        if isinstance(node.op, ast.Mod):
             # Heuristic: check if left operand is likely bytes
             # We can check if `left_type` (from _guess_type) starts with `[]u8`?
             # `_guess_type` returns `int` usually unless constant bytes.
             # visit_Constant bytes returns `[{...}]`
             # Let's check `left_type`.
             if left_type == "[]u8" or (isinstance(node.left, ast.Constant) and isinstance(node.left.value, bytes)):
                 return f"py_bytes_format({left}, {right})"

        if isinstance(node.op, ast.Pow):
             self.emitter.add_import("math")
             # Check types
             is_float_op = (left_type == "f64" or right_type == "f64")
             if is_float_op:
                  return f"math.pow({left}, {right})"
             else:
                  # Integer power
                  return f"math.powi({left}, {right})"

        op_map = {
            ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Div: "/",
            ast.Mod: "%",
            ast.BitAnd: "&", ast.BitOr: "|", ast.BitXor: "^",
            ast.LShift: "<<", ast.RShift: ">>"
        }

        # Check for string formatting: "string" % (args)
        if isinstance(node.op, ast.Mod):
             # Check if left is string
             is_string_fmt = False
             if isinstance(node.left, ast.Constant) and isinstance(node.left.value, str):
                 is_string_fmt = True
             elif left_type == "string":
                 is_string_fmt = True

             if is_string_fmt:
                 self.used_string_format = True
                 # Flatten arguments if tuple
                 fmt_args = right
                 if isinstance(node.right, ast.Tuple):
                      # We need individual args from visit(Tuple) which returns "[a, b]"
                      # This is tricky because visit(Tuple) returns a string representation of an array.
                      # We need the values.
                      # Re-visit elements of tuple individually.
                      arg_vals = [str(self.visit(elt)) for elt in node.right.elts]
                      fmt_args = ", ".join(arg_vals)

                 return f"py_string_format({left}, {fmt_args})"

        op_str = op_map.get(type(node.op), "?")
        return f"{left} {op_str} {right}"

    def visit_BoolOp(self, node: ast.BoolOp) -> str:
        op_map = {ast.And: "&&", ast.Or: "||"}
        op_str = op_map.get(type(node.op), "and")
        values = [str(self.visit(val)) for val in node.values]
        return f" {op_str} ".join(values)

    def visit_UnaryOp(self, node: ast.UnaryOp) -> str:
        operand = self.visit(node.operand)
        op_map = {
            ast.Not: "!", ast.UAdd: "+", ast.USub: "-",
            ast.Invert: "~"
        }
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

        if getattr(gen, 'is_async', False):
             self.output.append(f"{self._indent()}// TODO: Async comprehension - Verify iterator semantics")

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
        is_decl = target_var.isidentifier()
        op = ":=" if is_decl else "="
        mut_prefix = "mut " if is_decl else ""
        self.output.append(f"{self._indent()}{mut_prefix}{target_var} {op} map[{key_type}]{val_type}{{}}")

        if getattr(gen, 'is_async', False):
             self.output.append(f"{self._indent()}// TODO: Async comprehension - Verify iterator semantics")

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
             if isinstance(node.value, complex): return "PyComplex"
             return "int"
        elif isinstance(node, ast.Name):
            # Try to resolve via type inference
            inferred = self.type_inference.resolve_type(node)
            if inferred != "void":
                return inferred
            return "int" # Fallback
        elif isinstance(node, ast.BinOp):
            if isinstance(node.op, ast.Div):
                left = self._guess_type(node.left)
                right = self._guess_type(node.right)
                if left == "PyComplex" or right == "PyComplex": return "PyComplex"
                return "f64"
            # For Add/Sub/Mult/Mod/Pow, check operands
            left = self._guess_type(node.left)
            right = self._guess_type(node.right)
            if left == "PyComplex" or right == "PyComplex": return "PyComplex"
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
        is_decl = target_var.isidentifier()
        op = ":=" if is_decl else "="
        mut_prefix = "mut " if is_decl else ""
        self.output.append(f"{self._indent()}{mut_prefix}{target_var} {op} map[{key_type}]bool{{}}")

        if getattr(gen, 'is_async', False):
             self.output.append(f"{self._indent()}// TODO: Async comprehension - Verify iterator semantics")

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

    def visit_IfExp(self, node: ast.IfExp) -> str:
        test = self.visit(node.test)
        body = self.visit(node.body)
        orelse = self.visit(node.orelse)
        return f"if {test} {{ {body} }} else {{ {orelse} }}"
