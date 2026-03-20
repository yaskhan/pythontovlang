import ast
from typing import Any, List, Optional, Dict, Set, Tuple, TYPE_CHECKING


class FunctionGenerationMixin:
    if TYPE_CHECKING:
        def visit(self, node: ast.AST) -> Any: ...
        def _indent(self) -> str: ...
        _indent_level: int
        output: List[str]
        current_class: Optional[str]
        current_class_is_unittest: bool
        generic_variance: Dict[str, str]
        generic_defaults: Dict[str, str]
        type_params_map: Dict[str, List[str]]
        coroutine_handler: Any
        generic_scopes: List[Dict[str, str]]
        current_class_generics: List[str]
        type_inference: Any
        current_file_name: str
        defined_top_level_symbols: Set[str]
        overloaded_signatures: Dict[str, List[Dict[str, Any]]]
        function_names: Set[str]
        property_setters: Set[Tuple[str, str]]
        renamed_functions: Dict[str, str]
        defined_classes: Dict[str, Dict[str, Any]]
        config: Any
        _scope_stack: List[Set[str]]
        _scope_names: List[str]
        in_init: bool
        current_function_return_type: Optional[str]
        decorator_processor: Any
        emitter: Any
        name_remap: Dict[str, str]
        def _sanitize_name(self, name: str, is_type: bool = False) -> str: ...
        def _map_type(
            self,
            type_str: str,
            struct_name: Optional[str] = None,
            allow_union: bool = True,
            register_sum_types: bool = True,
            is_return: bool = False
        ) -> str: ...
        def _get_full_self_type(self, struct_name: Optional[str] = None) -> str: ...
        def _get_factory_name(self, class_name: str) -> str: ...
        def _mangle_name(self, name: str, class_name: Optional[str]) -> str: ...
        def _is_exported(self, name: str) -> bool: ...
        def _get_source_info(self, node: Optional[ast.AST] = None) -> str: ...
        def _extract_implicit_generics(self, node: Any) -> List[str]: ...
        def _get_generic_map(self, generics: List[str]) -> Dict[str, str]: ...
        def _get_all_active_v_generics(self) -> List[str]: ...
        def _get_generics_with_variance_str(self, generics: List[str]) -> str: ...
        def _generate_overload_variants(self, node: Any, struct_name: str, is_method: bool, dec_info: Any, is_generator: bool) -> None: ...
        def _find_captured_vars(self, node: ast.AST) -> List[str]: ...
        def _check_experimental_type(self, type_str: str, node: ast.AST) -> None: ...
        vexc_depth: int

    def _generate_function_for_struct(
        self,
        node: Any,
        is_async: bool,
        is_method: bool,
        struct_name: str,
        dec_info: Any,
        is_generator: bool,
        is_abstract: bool = False,
        force_standalone: bool = False,
    ) -> None:
        annotations_data: Dict[str, str] = {}
        # If we are distributing an abstract method to a descendant, skip it.
        # It only needs to be in the interface.
        if is_abstract and struct_name != self.current_class:
            return

        is_nested = len(self._scope_stack) > 0 and not force_standalone and not is_method

        old_output = self.output
        self.output = []
        old_indent = self._indent_level
        if not is_nested:
            self._indent_level = 0

        # Handle decorators and check for @warnings.deprecated
        is_deprecated = False
        deprecated_message: str | None = None

        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call):
                # Decorator with args: @dec(arg)
                func = self.visit(decorator.func)
                dec_args_list = []
                for dec_arg in decorator.args:
                    dec_args_list.append(str(self.visit(dec_arg)))
                for kw in decorator.keywords:
                    val = self.visit(kw.value)
                    dec_args_list.append(f"{kw.arg}={val}")
                dec_str = f"{func}({', '.join(dec_args_list)})"

                # Check for @warnings.deprecated("message")
                if func == "warnings.deprecated" and dec_args_list:
                    is_deprecated = True
                    # Extract message from first positional argument
                    msg = dec_args_list[0].strip("'\"")
                    deprecated_message = msg
            else:
                dec_str = self.visit(decorator)

            # Emit comments for all decorators as metadata
            self.output.append(f"// @{dec_str}")

        args_str_list: List[str] = []
        receiver_str: str = ""
        args_names: List[str] = []

        # Special handling for unittest methods: flatten to function calls
        is_unittest_method = False
        if (
            hasattr(self, "current_class_is_unittest")
            and self.current_class_is_unittest
        ):
            if node.name.startswith("test_"):
                is_unittest_method = True
                func_name = f"{node.name}_{struct_name}"
                is_method = False
                receiver_str = ""
            elif node.name in ("setUp", "tearDown"):
                self.output.append(f"// {node.name} method in unittest class ignored")
                return

        # Handle Python 3.12+ type_params (e.g. def foo[T](x: T):)
        func_generics_str = ""
        py_func_generics = []
        added_variance_keys = []
        added_default_keys = []
        if hasattr(node, "type_params") and node.type_params:
            for param in node.type_params:
                if hasattr(param, "name"):
                    name = param.name
                    if hasattr(name, "id"):
                        name = name.id

                    if isinstance(name, str):
                        py_func_generics.append(name)
                        # Extract variance (Python 3.13+)
                        variance = getattr(param, "variance", 0)
                        if variance == 1:
                            self.generic_variance[name] = "+"
                            added_variance_keys.append(name)
                        elif variance == 2:
                            self.generic_variance[name] = "-"
                            added_variance_keys.append(name)

                        # Extract default (PEP 696, Python 3.13+)
                        default_node = getattr(param, "default", None)
                        if default_node:
                            try:
                                default_str = ast.unparse(default_node)
                                v_default = self._map_type(default_str, struct_name)
                                self.generic_defaults[name] = v_default
                                added_default_keys.append(name)
                            except Exception:
                                pass

            # Record type params for runtime introspection
            full_func_name = f"{struct_name}_{self._sanitize_name(node.name)}" if is_method and struct_name else self._sanitize_name(node.name)
            self.type_params_map[full_func_name] = list(py_func_generics)

        # Extract implicit generics for pre-3.12 stubs or generic functions without type_params
        if not py_func_generics:
            implicit_generics = self._extract_implicit_generics(node)
            if implicit_generics:
                py_func_generics.extend(implicit_generics)
                full_func_name = f"{struct_name}_{self._sanitize_name(node.name)}" if is_method and struct_name else self._sanitize_name(node.name)
                self.type_params_map[full_func_name] = list(py_func_generics)

        func_generic_map = self._get_generic_map(py_func_generics)
        self.generic_scopes.append(func_generic_map)

        # V requires generic methods to explicitly repeat the struct generics
        # if the receiver is generic. E.g. fn (s Struct[T]) foo[T]()
        all_v_generics = self._get_all_active_v_generics()
        if all_v_generics:
            func_generics_str = self._get_generics_with_variance_str(all_v_generics)

        if is_generator:
            # Inject channel argument
            yield_type = self.coroutine_handler.get_yield_type(node)
            args_str_list.append(f"ch_out chan {yield_type}")
            args_str_list.append(f"ch_in chan PyGeneratorInput")
            self.coroutine_handler.enter_generator("ch_out", "ch_in")

        args = node.args.args
        if hasattr(node.args, "posonlyargs"):
            args = node.args.posonlyargs + args

        if hasattr(node.args, "kwonlyargs"):
            args = args + node.args.kwonlyargs

        # Check for __new__ or other static-like methods that might have 'cls'
        is_new_method = False
        original_node_name = node.name
        if node.name == "__new__":
            is_new_method = True
            if args and args[0].arg == "cls":
                args = args[1:]
            # Treat as static
            is_method = False
            receiver_str = ""

        if is_method and args and (args[0].arg == "self" or args[0].arg == "cls"):
            if not dec_info.is_static and not dec_info.is_classmethod:
                if args[0].arg == "self":
                    # fn (mut s Struct) method()
                    mut_receiver = "mut " if getattr(dec_info, 'is_setter', False) else ""
                    if self.current_class_generics:
                        # fn (mut s Struct[T]) method()
                        gen_str = f"[{', '.join(self.current_class_generics)}]"
                        receiver_str = f"({mut_receiver}{args[0].arg} {struct_name}{gen_str}) "
                    else:
                        receiver_str = f"({mut_receiver}{args[0].arg} {struct_name}) "
            elif dec_info.is_classmethod:
                # Class methods are static in V (no receiver)
                receiver_str = ""

            args = args[1:]  # Remove self/cls from arguments list
        elif is_unittest_method and args and args[0].arg == "self":
            # Remove self from unittest method args
            args = args[1:]

        is_stub_function = False
        if node.body and isinstance(node.body[0], ast.Expr) and isinstance(node.body[0].value, ast.Constant) and node.body[0].value.value is Ellipsis:
             is_stub_function = True

        args_len = len(node.args.args)
        defaults_len = len(node.args.defaults)
        defaults_map = {}
        for i, d in enumerate(node.args.defaults):
             arg_idx = args_len - defaults_len + i
             if arg_idx >= 0 and arg_idx < args_len:
                  defaults_map[node.args.args[arg_idx].arg] = d

        for i, kwarg in enumerate(node.args.kwonlyargs):
             if i < len(node.args.kw_defaults) and node.args.kw_defaults[i] is not None:
                  defaults_map[kwarg.arg] = node.args.kw_defaults[i]

        local_mut_copies = []

        for arg in args:
            arg_name = self._sanitize_name(arg.arg)
            if arg.annotation:
                try:
                    type_str = ast.unparse(arg.annotation)
                    self._check_experimental_type(type_str, arg.annotation)
                    arg_type = self._map_type(type_str, struct_name)
                except Exception:
                    default_type = "Any" if node.name == "__exit__" else "int"
                    arg_type = self._map_type(self.type_inference.type_map.get(arg_name, default_type), struct_name)
            else:
                default_type = "Any" if node.name == "__exit__" else "int"
                arg_type = self._map_type(self.type_inference.type_map.get(arg_name, default_type), struct_name)

            annotations_data[arg_name] = arg_type

            if (is_stub_function or self.current_file_name.endswith('.pyi')) and arg_type == "void":
                 continue

            args_names.append(arg_name)

            is_mut = False
            is_reassigned = False
            is_mutated_only = False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                prefix = ".".join(self._scope_names)
                qual_func_name = f"{prefix}.{node.name}" if prefix else node.name
                mut_info = self.type_inference.mutability_map.get(f"{qual_func_name}.{arg.arg}")
                if not mut_info:
                     mut_info = self.type_inference.mutability_map.get(arg.arg)

                if mut_info:
                    is_reassigned = mut_info.get("is_reassigned", False)
                    is_mutated_only = mut_info.get("is_mutated", False)
                    is_mut = is_reassigned or is_mutated_only

            clean_type = arg_type.lstrip('?')
            primitives = {"int", "string", "bool", "f32", "f64", "i64", "i16", "i8", "u8", "u16", "u32", "u64", "byte", "rune", "void", "any"}
            is_primitive = clean_type in primitives

            has_default = arg.arg in defaults_map

            # Use local mut copy if:
            # 1. Parameter has a default value and is mutated or reassigned (V doesn't allow 'mut' with default)
            # 2. Parameter is a primitive and is reassigned (standard V practice to avoid 'mut' in signature for primitives)
            if (has_default and is_mut) or (is_primitive and is_reassigned):
                local_mut_copies.append(arg_name)
                is_mut = False

            if is_mut and is_primitive:
                is_mut = False

            mut_prefix = "mut " if is_mut else ""
            args_str_list.append(f"{mut_prefix}{arg_name} {arg_type}")

        if node.args.vararg:
            arg_name = self._sanitize_name(node.args.vararg.arg)
            arg_type = "Any"  # Default
            if node.args.vararg.annotation:
                try:
                    type_str = ast.unparse(node.args.vararg.annotation)
                    arg_type = self._map_type(type_str, struct_name)
                except Exception:
                    pass
            else:
                inferred = self.type_inference.type_map.get(arg_name)
                if isinstance(inferred, str):
                    arg_type = self._map_type(inferred, struct_name)

            if is_nested:
                if not arg_type.startswith("[]"):
                    arg_type = f"[]{arg_type}"
                args_str_list.append(f"{arg_name} {arg_type}")
                annotations_data[arg_name] = arg_type
            else:
                if arg_type.startswith("[]"):
                    arg_type = arg_type[2:]
                args_str_list.append(f"{arg_name} ...{arg_type}")
                annotations_data[arg_name] = f"...{arg_type}"
            args_names.append(arg_name)

        if getattr(node, "args", None) and getattr(node.args, "vararg", None) and getattr(node.args, "kwarg", None):
            llm_comment = f"//##LLM@@ Function `{original_node_name}` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly."
            self.output.append(llm_comment)

        if node.args.kwarg:
            arg_name = self._sanitize_name(node.args.kwarg.arg)
            arg_type = "map[string]Any"
            if node.args.kwarg.annotation:
                try:
                    type_str = ast.unparse(node.args.kwarg.annotation)
                    arg_type = self._map_type(type_str, struct_name)
                except Exception:
                    pass
            else:
                inferred = self.type_inference.type_map.get(arg_name)
                if isinstance(inferred, str):
                    arg_type = self._map_type(inferred, struct_name)
            args_str_list.append(f"{arg_name} {arg_type}")
            args_names.append(arg_name)
            annotations_data[arg_name] = arg_type

        args_str = ", ".join(args_str_list)

        # Handle return types
        ret_type = "void"
        if not is_generator and node.returns:
            try:
                type_str = ast.unparse(node.returns)
                self._check_experimental_type(type_str, node.returns)
                ret_type = self._map_type(type_str, struct_name, is_return=True)
            except:
                if isinstance(node.returns, ast.Name):
                    ret_type = self._map_type(node.returns.id, struct_name, is_return=True)
                elif isinstance(node.returns, ast.Constant) and isinstance(
                    node.returns.value, str
                ):
                    ret_type = self._map_type(node.returns.value, struct_name, is_return=True)
        elif not is_generator and not node.returns:
            inferred_ret = self.type_inference.type_map.get(f"{node.name}@return")
            if isinstance(inferred_ret, str):
                 ret_type = inferred_ret
            elif node.name == "__enter__":
                for body_stmt in node.body:
                    if isinstance(body_stmt, ast.Return) and isinstance(body_stmt.value, ast.Name) and body_stmt.value.id == "self":
                        ret_type = self._get_full_self_type(struct_name)
                        break

        if ret_type != "void":
            annotations_data["return"] = ret_type

        is_noreturn = False
        if ret_type == "none":
            ret_type = "void"

        if ret_type == "void":
            try:
                if hasattr(ast, "unparse"):
                    ret_str = ast.unparse(node.returns)
                    if "NoReturn" in ret_str:
                        is_noreturn = True
            except:
                pass

        if not is_unittest_method:
            func_name = self._sanitize_name(node.name)
            if original_node_name == "__new__":
                func_name = self._get_factory_name(struct_name)

            if (dec_info.is_static or dec_info.is_classmethod) and original_node_name != "__new__":
                func_name = f"{struct_name}_{func_name}"

            if not is_method:
                self.defined_top_level_symbols.add(node.name)

            if original_node_name == "__next__" or func_name == "next":
                func_name = "next"
                if ret_type != "void" and not ret_type.startswith("?"):
                    ret_type = f"?{ret_type}"
            elif func_name in ("__enter__", "__aenter__"):
                func_name = "enter"
            elif func_name in ("__exit__", "__aexit__"):
                func_name = "exit"
            elif func_name == "__post_init__":
                func_name = "post_init"
            elif func_name == "__await__":
                func_name = "await_"
            elif func_name == "__iter__":
                func_name = "__iter__"

            # Check if this is the implementation of an overloaded function
            ov_key = f"{struct_name}.{original_node_name}" if is_method or original_node_name == "__new__" else original_node_name
            if ov_key in self.overloaded_signatures:
                self._generate_overload_variants(
                    node, struct_name, is_method, dec_info, is_generator
                )
                return

            self.function_names.add(func_name)

            if func_name == "__get__":
                func_name = "get"
            elif func_name == "__set__":
                func_name = "set"
            elif func_name == "__delete__":
                func_name = "delete"
            elif func_name == "__len__":
                func_name = "len"
            elif func_name == "__getitem__":
                func_name = "idx"

            if dec_info.is_setter:
                func_name = f"set_{func_name}"
                if struct_name:
                    self.property_setters.add((struct_name, node.name))

            if self.current_class and not is_new_method:
                func_name = self._mangle_name(func_name, struct_name)

            if func_name in self.renamed_functions:
                func_name = self.renamed_functions[func_name]

        if node.name == "__str__" or getattr(node, "original_name", "") == "__str__":
            func_name = "str"
        elif node.name == "__repr__" or getattr(node, "original_name", "") == "__repr__":
            if func_name != "str":
                func_name = "repr"

        # Handle cache wrapper generation
        if dec_info.cache_wrapper_needed and dec_info.implementation_name:
            wrapper_code = self.decorator_processor.generate_cache_wrapper(
                dec_info, func_name, args_str, ret_type, args_names, receiver_str
            )
            self.emitter.add_function(wrapper_code)
            func_name = dec_info.implementation_name

        is_init = False
        if "decl" not in locals() and func_name == "__init_subclass__":
            receiver_str = ""
            func_name = "init_subclass"
        elif func_name == "__init__":
            class_info = self.defined_classes.get(struct_name, {})
            is_pydantic = class_info.get("is_pydantic", False)
            if class_info.get("has_new"):
                func_name = "init"
            else:
                is_init = True
                func_name = self._get_factory_name(struct_name)
                receiver_str = ""  # Factory is static
                ret_type = struct_name
                if self.current_class_generics:
                    gen_str = f"[{', '.join(self.current_class_generics)}]"
                    ret_type += gen_str
                if is_pydantic:
                    ret_type = "!" + ret_type

        # Visibility handling
        pub_prefix = ""
        if not is_nested:
            if (not is_method and self._is_exported(node.name)) or (is_method and getattr(self, 'config', None) and not func_name.startswith('_') and not is_init):
                 pub_prefix = "pub "

            if is_init:
                 if self._is_exported(struct_name):
                      pub_prefix = "pub "

        noreturn_attr = "@[noreturn]\n" if is_noreturn else ""

        if getattr(self.config, 'source_mapping', False):
            self.output.append(f"// @line: {self._get_source_info(node)}")

        deprecated_attr = ""
        if is_deprecated:
            if deprecated_message:
                deprecated_attr = f"@[deprecated: '{deprecated_message}']\n"
            else:
                deprecated_attr = "@[deprecated]\n"

        elif is_method and func_name in (
            "__add__",
            "__sub__",
            "__mul__",
            "__truediv__",
            "__mod__",
            "__lt__",
            "__le__",
            "__eq__",
            "__ne__",
        ):
            # Operator overloading
            op_map = {
                "__add__": "+",
                "__sub__": "-",
                "__mul__": "*",
                "__truediv__": "/",
                "__mod__": "%",
                "__lt__": "<",
                "__le__": "<=",
                "__eq__": "==",
                "__ne__": "!=",
            }
            op = op_map.get(func_name)
            if op:
                func_name = op
                if ret_type == "void":
                    decl = f"{deprecated_attr}fn {receiver_str}{op} ({args_str}) {{"
                else:
                    decl = f"{deprecated_attr}fn {receiver_str}{op} ({args_str}) {ret_type} {{"
        elif func_name in ("__str__", "__repr__"):
            func_name = "str"
            decl = f"{deprecated_attr}fn {receiver_str}{func_name}() string {{"
        elif func_name == "__str__":
            decl = f"{noreturn_attr}{deprecated_attr}{pub_prefix}fn {receiver_str}str() string {{"
        elif func_name in ("__iter__", "iter"):
            func_name = "iter"
            if ret_type == "void" and struct_name:
                ret_type = self._get_full_self_type(struct_name)
            method_generics = func_generics_str
            if method_generics and self.current_class_generics and method_generics == f"[{', '.join(self.current_class_generics)}]":
                method_generics = ""

            if ret_type == "void":
                decl = f"{noreturn_attr}{deprecated_attr}{pub_prefix}fn {receiver_str}{func_name}{method_generics}({args_str}) {{"
            else:
                decl = f"{noreturn_attr}{deprecated_attr}{pub_prefix}fn {receiver_str}{func_name}{method_generics}({args_str}) {ret_type} {{"

        if dec_info.deprecated:
            if dec_info.deprecated_message:
                deprecated_attr = f"@[deprecated: '{dec_info.deprecated_message}']\n"
            else:
                deprecated_attr = "@[deprecated]\n"

        if "decl" not in locals():
            if original_node_name.startswith("__") and original_node_name.endswith("__") and func_name.startswith("__") and func_name.endswith("__"):
                self.output.append(f"{self._indent()}//##LLM@@ Unmapped Python dunder method (e.g., __call__, __getitem__) detected. V handles object behavior and operator overloading differently. Please implement the equivalent V logic or refactor the calling code.")

            if is_nested:
                captures = self._find_captured_vars(node)
                capture_str = f"[{', '.join(captures)}] " if captures else ""
                decl_op = ":="
                if func_name in self._scope_stack[-1]:
                    decl_op = "="

                if ret_type == "void":
                    decl = f"{self._indent()}mut {func_name} {decl_op} fn {capture_str}({args_str}) {{"
                else:
                    decl = f"{self._indent()}mut {func_name} {decl_op} fn {capture_str}({args_str}) {ret_type} {{"

                if getattr(node, "original_name", "") == "__str__":
                    decl = f"{self._indent()}fn {receiver_str}str() string {{"
                elif getattr(node, "original_name", "") == "__repr__":
                    decl = f"{self._indent()}fn {receiver_str}repr() string {{"
            else:
                if ret_type == "void":
                    decl = f"{noreturn_attr}{deprecated_attr}{pub_prefix}fn {receiver_str}{func_name}{func_generics_str}({args_str}) {{"
                else:
                    decl = f"{noreturn_attr}{deprecated_attr}{pub_prefix}fn {receiver_str}{func_name}{func_generics_str}({args_str}) {ret_type} {{"

        self.output.append(f"{decl}")
        self._indent_level += 1

        for line in dec_info.injected_start:
            self.output.append(f"{self._indent()}{line}")

        for line in dec_info.injected_end:
            self.output.append(f"{self._indent()}{line}")

        prev_in_init = getattr(self, "in_init", False)
        if is_init:
            self.in_init = True
            class_info = self.defined_classes.get(struct_name, {})
            if class_info.get("is_pydantic"):
                alloc_type = ret_type[1:] if ret_type.startswith("!") else ret_type
                self.output.append(f"{self._indent()}mut self := {alloc_type}{{}}")
            else:
                self.output.append(f"{self._indent()}mut self := {ret_type}{{}}")

        prev_ret_type: Optional[str] = getattr(self, "current_function_return_type", None)
        self.current_function_return_type = ret_type

        if is_nested:
            self._scope_stack[-1].add(func_name)

        current_scope = set(args_names)
        orig_args = node.args.args
        if hasattr(node.args, "posonlyargs"):
            orig_args = node.args.posonlyargs + orig_args

        if is_method and orig_args and orig_args[0].arg == "self" and not dec_info.is_static:
            current_scope.add(orig_args[0].arg)

        if dec_info.is_classmethod and orig_args and orig_args[0].arg == "cls":
            self.name_remap[orig_args[0].arg] = self._get_full_self_type(struct_name)
            current_scope.add(orig_args[0].arg)

        self._scope_stack.append(current_scope)
        self._scope_names.append(node.name)

        try:
            body = node.body
            if (
                body
                and isinstance(body[0], ast.Expr)
                and isinstance(body[0].value, ast.Constant)
                and isinstance(body[0].value.value, str)
            ):
                doc = body[0].value.value.strip()
                for line in doc.splitlines():
                    self.output.append(f"{self._indent()}// {line}")
                body = body[1:]

            if is_generator:
                self.output.append(
                    f"{self._indent()}_ := <-{self.coroutine_handler.active_in_channel}"
                )

            for arg_copy_name in local_mut_copies:
                self.output.append(f"{self._indent()}mut {arg_copy_name} := {arg_copy_name}")

            for stmt in body:
                self.visit(stmt)
        finally:
            if dec_info.is_classmethod and orig_args and orig_args[0].arg == "cls":
                del self.name_remap[orig_args[0].arg]
            self.current_function_return_type = prev_ret_type
            self._scope_stack.pop()
            self._scope_names.pop()

        self.generic_scopes.pop()

        for k in added_variance_keys:
            if k in self.generic_variance:
                del self.generic_variance[k]
        for k in added_default_keys:
            if k in self.generic_defaults:
                del self.generic_defaults[k]

        if is_generator:
            self.output.append(
                f"{self._indent()}{self.coroutine_handler.active_channel}.close()"
            )
            self.coroutine_handler.exit_generator()

        if is_init:
            class_info = self.defined_classes.get(struct_name, {})
            if class_info.get("is_pydantic"):
                self.output.append(f"{self._indent()}self.validate() or {{ return err }}")
            self.output.append(f"{self._indent()}return self")
            self.in_init = prev_in_init

        self._indent_level -= 1
        self.output.append(f"{self._indent()}}}")

        func_code = "\n".join(self.output)
        if is_nested:
            old_output.append(func_code)
        else:
            self.emitter.add_function(func_code)
            # Emit annotations metadata constant if there are any annotations
            if not is_unittest_method and not is_abstract and annotations_data:
                pub = "pub " if pub_prefix else ""
                anno_map = ", ".join([f"'{k}': '{v}'" for k, v in annotations_data.items()])
                # Use a unique name for the constant to avoid duplicates when mixins are distributed
                const_name = f"{struct_name}_{func_name}__annotations__" if is_method and struct_name else f"{func_name}__annotations__"
                self.emitter.add_constant(f"{pub}{const_name} = {{ {anno_map} }}")

        self.output = old_output
        self._indent_level = old_indent
