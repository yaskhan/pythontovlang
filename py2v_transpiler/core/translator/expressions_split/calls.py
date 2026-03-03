import ast
from typing import List, Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v

class CallsMixin(TranslatorBase):
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

        if module_name == "six":
            if func_name == "u" and len(args) == 1:
                return args[0]
            elif func_name == "text_type" and len(args) == 1:
                return f"{args[0]}.str()"

        if module_name == "os" and func_name == "open":
             # Handle open() -> os.open()
             self.emitter.add_import("os")
             if len(args) >= 1:
                 # In V: os.open(path) returns ?File, so we unwrap it.
                 # Assuming read mode for simplicity as mapped from open(path)
                 return f"os.open({args[0]}) or {{ panic(err) }}"

        if module_name == "builtins":
            if func_name == "hasattr":
                 if len(args) >= 2:
                     obj_expr = args[0]
                     obj_type = self._guess_type(node.args[0])

                     if isinstance(node.args[1], ast.Constant) and isinstance(node.args[1].value, str):
                         attr_name = node.args[1].value
                         # Primitive types definitely don't have custom attributes
                         if obj_type in ("int", "f64", "bool", "string", "[]u8"):
                             return "false"

                         # If we know it's a specific struct and know its fields (dataclass)
                         if obj_type != "Any" and hasattr(self, 'dataclasses') and obj_type in self.dataclasses:
                             if attr_name in self.dataclasses[obj_type]:
                                 return "true"
                             else:
                                 # We don't have all fields stored, so fallback to compile-time introspection
                                 return f"$if {obj_expr}.has_field('{attr_name}') {{ true }} $else {{ false }}"

                         # Unknown struct or Any/Union -> compile-time introspection fallback
                         return f"$if {obj_expr}.has_field('{attr_name}') {{ true }} $else {{ false }}"

                     return f"/* hasattr({', '.join(args)}) - reflection not fully supported */ false"
                 return "false"
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
            # Check for typing.cast before using standard mapper so we have AST node access
            if module_name == "typing" and func_name == "cast":
                if len(args) == 2:
                    try:
                        type_str = ast.unparse(node.args[0])
                        from py2v_transpiler.models.v_types import map_python_type_to_v
                        v_type = map_python_type_to_v(type_str)
                    except Exception:
                        v_type = str(self.visit(node.args[0]))
                    val = args[1]
                    return f"({val} as {v_type})"
                return f"/* typing.cast missing args */"

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
                 # partial(func, *args) -> fn [func, args] (extra_args ...Any) { return func(args..., extra_args...) }
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
                 # `fn [target_func, partial_args] (rest ...Any) { return target_func(partial_args..., rest...) }`

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
                 # Fallback: Emit a comment and a best-effort lambda assuming 'int' or 'Any' if possible.

                 # Try to deduce type from target_func? Hard.

                 # Let's emit a closure that takes `...int` and returns `int` as a common case,
                 # or `...Any` if we had `Any` support everywhere.

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

        # Handle super().method() and super(Class, self).method()
        if isinstance(func_node, ast.Attribute) and isinstance(func_node.value, ast.Call):
            is_super = False
            if isinstance(func_node.value.func, ast.Name) and func_node.value.func.id == "super":
                is_super = True

            if is_super:
                method_name = func_node.attr
                if self.current_class_bases:
                    parent = self.current_class_bases[0]
                    if method_name == "__init__":
                        return f"self.{parent} = new_{parent}({', '.join(args)})"
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

        # Extract mypy plugin signature if available for this call
        loc_key = f"{getattr(node, 'lineno', 0)}:{getattr(node, 'col_offset', 0)}"
        call_sig = None
        if hasattr(self.type_inference, "call_signatures"):
            for k, v in self.type_inference.call_signatures.items():
                if k.endswith(f".{func_name_str}@{loc_key}"):
                    call_sig = v
                    break
            if not call_sig:
                for k, v in self.type_inference.call_signatures.items():
                    if k.endswith(f"@{loc_key}"):
                        if func_name_str in k:
                            call_sig = v
                            break
            if not call_sig:
                for k, v in self.type_inference.call_signatures.items():
                    if k == loc_key:
                        call_sig = v
                        break

        # Handle overloaded functions
        if func_name_str in getattr(self, "overloaded_signatures", {}):
            # We need to find the correct overload variant

            type_suffix_parts = []
            if call_sig and "args" in call_sig:
                # We use the argument types resolved by mypy
                for arg_typ in call_sig["args"]:
                    # Mypy arg types can be complex (e.g. 'Literal[1]?'), we need to map them back to our V types
                    # First normalize mypy specific literal formatting: 'Literal[1]?' -> 'int'
                    norm_typ = arg_typ.replace("builtins.", "")
                    if "Literal[" in arg_typ:
                        if "'" in arg_typ or '"' in arg_typ:
                            norm_typ = "str"
                        else:
                            norm_typ = "int"
                    try:
                        v_type = map_python_type_to_v(norm_typ)
                    except Exception:
                        v_type = "Any"
                    # Ensure we map mypy's builtins correctly, even if mapping failed
                    if v_type == "builtins.int" or norm_typ == "builtins.int" or norm_typ == "int": v_type = "int"
                    if v_type == "builtins.str" or norm_typ == "builtins.str" or norm_typ == "str": v_type = "string"
                    if v_type == "builtins.float" or norm_typ == "builtins.float" or norm_typ == "float": v_type = "f64"
                    if v_type == "builtins.bool" or norm_typ == "builtins.bool" or norm_typ == "bool": v_type = "bool"
                    clean_type = v_type.replace("?", "opt_").replace("[]", "arr_").replace("[", "_").replace("]", "").replace(".", "_")
                    type_suffix_parts.append(clean_type)
            else:
                # Fallback: guess types from arguments if mypy didn't track it
                for arg in node.args:
                    arg_type = self._guess_type(arg)
                    clean_type = arg_type.replace("?", "opt_").replace("[]", "arr_").replace("[", "_").replace("]", "").replace(".", "_")
                    type_suffix_parts.append(clean_type)

            # We want to match against the *defined* overload variants, because mypy might infer
            # slightly different types than what was declared in the overload (e.g. `int` instead of `Any`).
            # Find the best match among `self.overloaded_signatures[func_name_str]`.
            best_match_suffix = None
            if func_name_str in self.overloaded_signatures:
                for sig in self.overloaded_signatures[func_name_str]:
                    sig_suffix_parts = []
                    for arg in sig["args"]:
                        sig_type = arg["type"]
                        clean_sig_type = sig_type.replace("?", "opt_").replace("[]", "arr_").replace("[", "_").replace("]", "").replace(".", "_")
                        sig_suffix_parts.append(clean_sig_type)

                    # Exact match
                    if sig_suffix_parts == type_suffix_parts:
                        best_match_suffix = "_".join(sig_suffix_parts)
                        break

            # Operator overloading: if the method is an operator, don't mangle the call site,
            # because V handles operators intrinsically if they are mapped correctly.
            # But wait, python ast maps operators (e.g. `a + b`) to `BinOp(Add)`, which we already translate
            # to `a + b` in `OperatorsMixin.visit_BinOp`.
            # What if someone calls `a.__add__(b)` directly?
            # V does not allow calling operators as methods (`a.+(b)`).
            # We must map `__add__` to `+`.
            op_map = {
                "__add__": "+", "__sub__": "-", "__mul__": "*", "__truediv__": "/",
                "__mod__": "%", "__lt__": "<", "__le__": "<=", "__eq__": "==",
                "__ne__": "!="
            }
            if func_name_str in op_map:
                op_str = op_map[func_name_str]
                # If we are in obj.method(arg), then we need to restructure it to obj + arg
                if len(args) == 1 and isinstance(node.func, ast.Attribute):
                    obj = self.visit(node.func.value)
                    return f"{obj} {op_str} {args[0]}"
                # Fallback if something weird happened (e.g. called without args)
                pass

            if best_match_suffix:
                func_name_str = f"{func_name_str}_{best_match_suffix}"
            elif type_suffix_parts:
                # If no exact match, we use the inferred types to build the name.
                # This guarantees we call the specific overloaded variant matching the static types.
                # If mypy successfully inferred the types but the call doesn't match an overload,
                # the V compiler will correctly throw an error indicating a missing function.
                func_name_str = f"{func_name_str}_{'_'.join(type_suffix_parts)}"
            else:
                func_name_str = f"{func_name_str}_noargs"

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

        # Handle standard class instantiation
        is_class = False
        has_init = False
        if call_sig and "is_class" in call_sig:
            is_class = call_sig["is_class"]
            has_init = call_sig.get("has_init", False)
        elif hasattr(self, 'defined_classes') and func_name_str in self.defined_classes:
            is_class = True
            has_init = self.defined_classes[func_name_str]

        if is_class:
            if has_init:
                return f"new_{func_name_str}({', '.join(args)})"
            else:
                return f"{func_name_str}{{{', '.join(args)}}}"

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

        # Handle list.sort(reverse=True)
        if isinstance(func_node, ast.Attribute) and func_node.attr == "sort":
             # We assume it is a list sort call if method name is 'sort'
             # Check keywords for reverse=True
             reverse = False
             for keyword in node.keywords:
                 if keyword.arg == "reverse":
                     if isinstance(keyword.value, ast.Constant) and keyword.value.value is True:
                         reverse = True

             obj = self.visit(func_node.value)
             if reverse:
                 return f"{obj}.sort(a > b)"
             else:
                 return f"{obj}.sort()"

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

        elif func_name_str == "round":
            self.emitter.add_import("math")
            if len(args) == 2:
                self.used_builtins.add("round")
                return f"py_round(f64({args[0]}), {args[1]})"
            elif len(args) == 1:
                return f"math.round({args[0]})"


        elif func_name_str == "float":
            if len(args) == 1:
                return f"f64({args[0]})"
            return "0.0"

        elif func_name_str == "isinstance":
            if len(args) == 2:
                obj = args[0]
                types = args[1]
                # Check if second arg was a Tuple, visited as "[T1, T2]" string
                # We need to access the original node to be sure
                if isinstance(node.args[1], ast.Tuple):
                    # It's a tuple of types: (int, float)
                    # We need to generate (obj is int || obj is float)
                    type_checks = []
                    for elt in node.args[1].elts:
                        t_name = str(self.visit(elt))
                        type_checks.append(f"{obj} is {t_name}")
                    return f"({' || '.join(type_checks)})"

                if types.startswith("[") and types.endswith("]"):
                     return f"/* isinstance({obj}, {types}) - multi-type check not supported */ false"
                return f"{obj} is {types}"

        elif func_name_str == "assert_never":
            if len(args) == 1:
                return f"panic('assert_never reached: ${{{args[0]}}}')"
            return "panic('assert_never reached')"

        elif func_name_str == "assert_type":
            if len(args) >= 2:
                # Compile-time evaluation of assert_type
                # args[0] is the expression, args[1] is the type
                # We need the actual AST node of the type to map it correctly
                expr_node = node.args[0]
                type_node = node.args[1]

                expr_type = self._guess_type(expr_node)

                try:
                    type_str = ast.unparse(type_node)
                    # For assert_type error messages, it might be better to compare original mapped type names
                    # but map_python_type_to_v converts float to f64, so test expects f64.
                    from py2v_transpiler.models.v_types import map_python_type_to_v as local_map_fn
                    expected_type = local_map_fn(type_str)
                except Exception:
                    # Fallback if unparse fails
                    type_str = str(self.visit(type_node))
                    from py2v_transpiler.models.v_types import map_python_type_to_v as local_map_fn
                    expected_type = local_map_fn(type_str)

                if expr_type == expected_type:
                    return f"// assert_type({args[0]}, {expected_type}) passed statically"
                else:
                    return f"$compile_error('assert_type failed: expected {expected_type} but got {expr_type}')"
            return "// assert_type requires 2 arguments"

        elif func_name_str == "input":
            self.emitter.add_import("os")
            if args:
                return f"os.input({args[0]})"
            return "os.input('')"

        # String predicates
        # isdigit, isalpha, isalnum, isspace, islower, isupper, istitle, startswith, endswith
        # These are usually called as methods on strings: "s.isdigit()"
        # But visit_Call handles method calls too.
        # Check if the function name matches a known string predicate.
        # And implicitly assume the receiver is a string (or we rely on V compiler error if not).
        # We handle them if func_node is Attribute.
        elif isinstance(func_node, ast.Attribute) and func_node.attr in (
            "isdigit", "isalpha", "isalnum", "isspace", "islower", "isupper", "istitle", "startswith", "endswith"
        ) and not module_name:
             attr = func_node.attr
             obj = self.visit(func_node.value)
             if attr == "isdigit":
                 return f"{obj}.bytes().all(it.is_digit())"
             elif attr == "isalpha":
                 return f"{obj}.bytes().all(it.is_letter())"
             elif attr == "isalnum":
                 return f"{obj}.bytes().all(it.is_alnum())"
             elif attr == "isspace":
                 return f"{obj}.bytes().all(it.is_space())"
             elif attr == "islower":
                 return f"{obj}.is_lower()"
             elif attr == "isupper":
                 return f"{obj}.is_upper()"
             elif attr == "istitle":
                 return f"{obj}.is_title()"
             elif attr in ("startswith", "endswith"):
                 v_method = "starts_with" if attr == "startswith" else "ends_with"
                 if len(node.args) == 1 and isinstance(node.args[0], ast.Tuple):
                     checks = []
                     for elt in node.args[0].elts:
                         elt_str = self.visit(elt)
                         checks.append(f"{obj}.{v_method}({elt_str})")
                     return f"({' || '.join(checks)})"
                 else:
                     # Handled by standard mapping or method call fallback if not tuple
                     # But for normal strings we might want to just output it here if we handled it
                     # V uses starts_with/ends_with.
                     if len(node.args) == 1:
                         elt_str = self.visit(node.args[0])
                         return f"{obj}.{v_method}({elt_str})"
                     # Fallback to default if more complex
                     pass

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
