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
        current_class_body: List[ast.stmt]
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
        def _get_v_default_value(self, v_type: str) -> str: ...
        def _is_empty_body(self, body: List[ast.stmt]) -> bool: ...
        def _get_all_active_v_generics(self) -> List[str]: ...
        def _get_generics_with_variance_str(self, generics: List[str]) -> str: ...
        def _generate_overload_variants(self, node: Any, struct_name: str, is_method: bool, dec_info: Any, is_generator: bool) -> None: ...
        def _find_captured_vars(self, node: ast.AST) -> List[str]: ...
        def _check_experimental_type(self, type_str: str, node: ast.AST) -> None: ...

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
        if is_abstract and struct_name != self.current_class: return
        is_nested = len(self._scope_stack) > 0 and not force_standalone and not is_method
        old_output, self.output = self.output, []
        old_indent = self._indent_level
        if not is_nested: self._indent_level = 0
        is_deprecated, deprecated_message = False, None
        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call):
                func = self.visit(decorator.func)
                dec_args_list = [str(self.visit(da)) for da in decorator.args] + [f"{kw.arg}={self.visit(kw.value)}" for kw in decorator.keywords]
                dec_str = f"{func}({', '.join(dec_args_list)})"
                if func == "warnings.deprecated" and dec_args_list: is_deprecated, deprecated_message = True, dec_args_list[0].strip("'\"")
            else: dec_str = self.visit(decorator)
            self.output.append(f"// @{dec_str}")
        args_str_list, receiver_str, args_names = [], "", []
        is_unittest_method = False
        if getattr(self, "current_class_is_unittest", False):
            if node.name.startswith("test_"): is_unittest_method, func_name, is_method, receiver_str = True, f"{node.name}_{struct_name}", False, ""
            elif node.name in ("setUp", "tearDown"): self.output.append(f"// {node.name} method in unittest class ignored"); return
        func_generics_str, py_func_generics, added_variance_keys, added_default_keys = "", [], [], []
        if hasattr(node, "type_params") and node.type_params:
            for param in node.type_params:
                p_name = param.name.id if hasattr(param.name, "id") else param.name
                if isinstance(p_name, str):
                    py_func_generics.append(p_name)
                    if getattr(param, "variance", 0) == 1: self.generic_variance[p_name] = "+" ; added_variance_keys.append(p_name)
                    elif getattr(param, "variance", 0) == 2: self.generic_variance[p_name] = "-" ; added_variance_keys.append(p_name)
                    if getattr(param, "default", None):
                        try: self.generic_defaults[p_name] = self._map_type(ast.unparse(param.default), struct_name); added_default_keys.append(p_name)
                        except: pass
            full_func_name = f"{struct_name}_{self._sanitize_name(node.name)}" if is_method and struct_name else self._sanitize_name(node.name)
            self.type_params_map[full_func_name] = list(py_func_generics)
        if not py_func_generics:
            implicit_generics = self._extract_implicit_generics(node)
            if implicit_generics:
                py_func_generics.extend(implicit_generics)
                full_func_name = f"{struct_name}_{self._sanitize_name(node.name)}" if is_method and struct_name else self._sanitize_name(node.name)
                self.type_params_map[full_func_name] = list(py_func_generics)
        self.generic_scopes.append(self._get_generic_map(py_func_generics))
        all_v_generics = self._get_all_active_v_generics()
        if all_v_generics: func_generics_str = self._get_generics_with_variance_str(all_v_generics)
        if is_generator:
            yield_type = self.coroutine_handler.get_yield_type(node)
            args_str_list.extend([f"ch_out chan {yield_type}", "ch_in chan PyGeneratorInput"])
            self.coroutine_handler.enter_generator("ch_out", "ch_in")
        args = (node.args.posonlyargs if hasattr(node.args, "posonlyargs") else []) + node.args.args + (node.args.kwonlyargs if hasattr(node.args, "kwonlyargs") else [])
        is_new_method, original_node_name = False, getattr(node, "original_name", node.name)
        if original_node_name == "__new__":
            is_new_method = True
            if args and args[0].arg == "cls": args = args[1:]
            is_method, receiver_str = False, ""
        if is_method and args and args[0].arg in ("self", "cls"):
            if not dec_info.is_static and not dec_info.is_classmethod:
                if args[0].arg == "self":
                    mut_pfx = "mut " if getattr(dec_info, 'is_setter', False) else ""
                    gen_s = f"[{', '.join(self.current_class_generics)}]" if self.current_class_generics else ""
                    receiver_str = f"({mut_pfx}{args[0].arg} {struct_name}{gen_s}) "
            args = args[1:]
        elif is_unittest_method and args and args[0].arg == "self": args = args[1:]
        defaults_map = {node.args.args[len(node.args.args)-len(node.args.defaults)+i].arg: d for i, d in enumerate(node.args.defaults)}
        for i, kwarg in enumerate(node.args.kwonlyargs):
             if i < len(node.args.kw_defaults) and node.args.kw_defaults[i]: defaults_map[kwarg.arg] = node.args.kw_defaults[i]
        local_mut_copies = []
        for arg in args:
            arg_name = self._sanitize_name(arg.arg)
            try: arg_type = self._map_type(ast.unparse(arg.annotation), struct_name) if arg.annotation else self._map_type(self.type_inference.type_map.get(arg_name, "Any" if node.name == "__exit__" else "int"), struct_name)
            except: arg_type = self._map_type(self.type_inference.type_map.get(arg_name, "int"), struct_name)
            annotations_data[arg_name] = arg_type
            args_names.append(arg_name)
            is_mut, is_reassigned = False, False
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                prefix = ".".join(self._scope_names)
                m_info = self.type_inference.mutability_map.get(f"{prefix}.{node.name}.{arg.arg}") or self.type_inference.mutability_map.get(arg.arg)
                if m_info: is_reassigned, is_mut = m_info.get("is_reassigned", False), m_info.get("is_reassigned", False) or m_info.get("is_mutated", False)
            if (arg.arg in defaults_map and is_mut) or (arg_type.lstrip('?') in {"int", "string", "bool", "f32", "f64", "i64", "i16", "i8", "u8", "u16", "u32", "u64", "byte", "rune", "void", "any"} and is_reassigned):
                local_mut_copies.append(arg_name); is_mut = False
            if is_mut and arg_type.lstrip('?') in {"int", "string", "bool", "f32", "f64", "i64", "i16", "i8", "u8", "u16", "u32", "u64", "byte", "rune", "void", "any"}: is_mut = False
            args_str_list.append(f"{'mut ' if is_mut else ''}{arg_name} {arg_type}")
        if node.args.vararg:
            arg_name = self._sanitize_name(node.args.vararg.arg)
            try: arg_type = self._map_type(ast.unparse(node.args.vararg.annotation), struct_name) if node.args.vararg.annotation else self._map_type(self.type_inference.type_map.get(arg_name, "Any"), struct_name)
            except: arg_type = "Any"
            if is_nested:
                if not arg_type.startswith("[]"): arg_type = f"[]{arg_type}"
                args_str_list.append(f"{arg_name} {arg_type}"); annotations_data[arg_name] = arg_type
            else:
                if arg_type.startswith("[]"): arg_type = arg_type[2:]
                args_str_list.append(f"{arg_name} ...{arg_type}"); annotations_data[arg_name] = f"...{arg_type}"
            args_names.append(arg_name)
        if getattr(node, "args", None) and node.args.vararg and node.args.kwarg: self.output.append(f"//##LLM@@ Function `{original_node_name}` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.")
        if node.args.kwarg:
            arg_name = self._sanitize_name(node.args.kwarg.arg)
            try: arg_type = self._map_type(ast.unparse(node.args.kwarg.annotation), struct_name) if node.args.kwarg.annotation else self._map_type(self.type_inference.type_map.get(arg_name, "map[string]Any"), struct_name)
            except: arg_type = "map[string]Any"
            args_str_list.append(f"{arg_name} {arg_type}"); args_names.append(arg_name); annotations_data[arg_name] = arg_type
        args_str = ", ".join(args_str_list)
        ret_type = "void"
        if not is_generator:
            if node.returns:
                try:
                    type_str = ast.unparse(node.returns)
                    self._check_experimental_type(type_str, node.returns)
                    ret_type = self._map_type(type_str, struct_name, is_return=True)
                except:
                    if isinstance(node.returns, ast.Name): ret_type = self._map_type(node.returns.id, struct_name, is_return=True)
                    elif isinstance(node.returns, ast.Constant) and isinstance(node.returns.value, str): ret_type = self._map_type(node.returns.value, struct_name, is_return=True)
            else:
                inferred_ret = self.type_inference.type_map.get(f"{node.name}@return")
                if isinstance(inferred_ret, str): ret_type = inferred_ret
                elif node.name == "__enter__":
                    for bs in node.body:
                        if isinstance(bs, ast.Return) and isinstance(bs.value, ast.Name) and bs.value.id == "self": ret_type = self._get_full_self_type(struct_name); break
        if dec_info.is_setter:
            ret_type = "void"
        if ret_type != "void": annotations_data["return"] = ret_type
        is_noreturn = False
        if ret_type == "none": ret_type = "void"
        if ret_type == "void":
            try:
                if hasattr(ast, "unparse") and "NoReturn" in ast.unparse(node.returns): is_noreturn = True
            except: pass
        if not is_unittest_method:
            func_name = self._sanitize_name(node.name)
            if original_node_name == "__new__": func_name = self._get_factory_name(struct_name)
            if (dec_info.is_static or dec_info.is_classmethod) and original_node_name != "__new__": func_name = f"{struct_name}_{func_name}"
            if not is_method: self.defined_top_level_symbols.add(node.name)
            if original_node_name == "__next__" or func_name == "next":
                func_name = "next"
                if ret_type != "void" and not ret_type.startswith("?"): ret_type = f"?{ret_type}"
            elif original_node_name in ("__enter__", "__aenter__"): func_name = "enter"
            elif original_node_name in ("__exit__", "__aexit__"): func_name = "exit"
            elif original_node_name == "__post_init__": func_name = "post_init"
            elif original_node_name == "__await__": func_name = "await_"
            elif original_node_name == "__iter__": func_name = "iter"
            ov_key = f"{struct_name}.{original_node_name}" if is_method or original_node_name == "__new__" else original_node_name
            if ov_key in self.overloaded_signatures:
                self._generate_overload_variants(node, struct_name, is_method, dec_info, is_generator); return
            self.function_names.add(func_name)
            if original_node_name == "__get__": func_name = "get"
            elif original_node_name == "__set__": func_name = "set"
            elif original_node_name == "__delete__": func_name = "delete"
            elif original_node_name == "__len__": func_name = "len"
            elif original_node_name == "__getitem__": func_name = "idx"
            if dec_info.is_setter:
                func_name = f"set_{func_name}"
                if struct_name: self.property_setters.add((struct_name, node.name))
            if self.current_class and not is_new_method: func_name = self._mangle_name(func_name, struct_name)
            if func_name in self.renamed_functions: func_name = self.renamed_functions[func_name]

        if dec_info.cache_wrapper_needed and dec_info.implementation_name:
            self.emitter.add_function(self.decorator_processor.generate_cache_wrapper(dec_info, func_name, args_str, ret_type, args_names, receiver_str))
            func_name = dec_info.implementation_name
        is_init = False
        if "decl" not in locals() and original_node_name == "__init_subclass__": receiver_str, func_name = "", "init_subclass"
        elif original_node_name == "__init__":
            if self.defined_classes.get(struct_name, {}).get("has_new"): func_name = "init"
            else:
                is_init, func_name, receiver_str, ret_type = True, self._get_factory_name(struct_name), "", struct_name
                if self.current_class_generics: ret_type += f"[{', '.join(self.current_class_generics)}]"
                if self.defined_classes.get(struct_name, {}).get("is_pydantic"): ret_type = "!" + ret_type
        pub_pfx = "pub " if (not is_nested and ((not is_method and self._is_exported(node.name)) or (is_method and getattr(self, 'config', None) and not func_name.startswith('_') and not is_init) or (is_init and self._is_exported(struct_name)))) else ""
        if getattr(self.config, 'source_mapping', False): self.output.append(f"// @line: {self._get_source_info(node)}")
        dep_attr = f"@[deprecated: '{deprecated_message}']\n" if is_deprecated and deprecated_message else "@[deprecated]\n" if is_deprecated or dec_info.deprecated else ""
        nor_attr = "@[noreturn]\n" if is_noreturn else ""
        if "decl" not in locals():
            if original_node_name.startswith("__") and original_node_name.endswith("__") and func_name.startswith("__") and func_name.endswith("__"):
                self.output.append(f"{self._indent()}//##LLM@@ Unmapped Python dunder method detected.")
            if original_node_name in ("__str__", "__repr__"):
                decl = f"{dep_attr}fn {receiver_str}{func_name}() string {{"
            elif is_method and original_node_name in ("__add__", "__sub__", "__mul__", "__truediv__", "__mod__", "__lt__", "__le__", "__eq__", "__ne__"):
                op = {"__add__": "+", "__sub__": "-", "__mul__": "*", "__truediv__": "/", "__mod__": "%", "__lt__": "<", "__le__": "<=", "__eq__": "==", "__ne__": "!="}.get(original_node_name)
                ret_type_str = f" {ret_type}" if ret_type and ret_type != 'void' else ""
                decl = f"{dep_attr}fn {receiver_str}{op} ({args_str}){ret_type_str} {{"
            elif original_node_name in ("__iter__", "iter"):
                func_name = "iter"
                if ret_type == "void" and struct_name: ret_type = self._get_full_self_type(struct_name)
                m_gens = "" if func_generics_str and self.current_class_generics and func_generics_str == f"[{', '.join(self.current_class_generics)}]" else func_generics_str
                ret_type_str = f" {ret_type}" if ret_type and ret_type != 'void' else ""
                decl = f"{nor_attr}{dep_attr}{pub_pfx}fn {receiver_str}{func_name}{m_gens}({args_str}){ret_type_str} {{"
            elif is_nested:
                captures = self._find_captured_vars(node)
                c_str = f"[{', '.join(captures)}] " if captures else ""
                ret_type_str = f" {ret_type}" if ret_type and ret_type != 'void' else ""
                decl = f"{self._indent()}mut {func_name} {'=' if func_name in self._scope_stack[-1] else ':='} fn {c_str}({args_str}){ret_type_str} {{"
            else:
                ret_type_str = f" {ret_type}" if ret_type and ret_type != 'void' else ""
                decl = f"{nor_attr}{dep_attr}{pub_pfx}fn {receiver_str}{func_name}{func_generics_str}({args_str}){ret_type_str} {{"
        self.output.append(f"{decl}"); self._indent_level += 1
        for line in dec_info.injected_start + dec_info.injected_end: self.output.append(f"{self._indent()}{line}")
        prev_in_init = getattr(self, "in_init", False)
        if is_init:
            self.in_init = True
            alloc_type = ret_type[1:] if ret_type.startswith("!") else ret_type
            if self.defined_classes.get(struct_name, {}).get("is_pydantic"):
                 self.output.append(f"{self._indent()}mut self := {alloc_type}{{}}")
            else:
                 self.output.append(f"{self._indent()}mut self := {ret_type}{{}}")
        prev_ret_type, self.current_function_return_type = getattr(self, "current_function_return_type", None), ret_type
        if is_nested: self._scope_stack[-1].add(func_name)
        cur_scope = set(args_names)
        orig_args = (node.args.posonlyargs if hasattr(node.args, "posonlyargs") else []) + node.args.args
        if is_method and orig_args and orig_args[0].arg == "self" and not dec_info.is_static: cur_scope.add(orig_args[0].arg)
        if dec_info.is_classmethod and orig_args and orig_args[0].arg == "cls": self.name_remap[orig_args[0].arg] = self._get_full_self_type(struct_name); cur_scope.add(orig_args[0].arg)
        self._scope_stack.append(cur_scope); self._scope_names.append(node.name)
        saved_cond_optional = dict(getattr(self, '_cond_optional_var_type', {}))
        if hasattr(self, '_cond_optional_var_type'):
            self._cond_optional_var_type.clear()
        try:
            body = node.body
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
                for line in body[0].value.value.strip().splitlines(): self.output.append(f"{self._indent()}// {line}")
                body = body[1:]
            if is_generator: self.output.append(f"{self._indent()}_ := <-{self.coroutine_handler.active_in_channel}")
            for a_copy in local_mut_copies: self.output.append(f"{self._indent()}mut {a_copy} := {a_copy}")
            if self._is_empty_body(body) and ret_type != "void": self.output.append(f"{self._indent()}return {self._get_v_default_value(ret_type)}")
            else:
                for stmt in body:
                    self.visit(stmt)
        finally:
            if dec_info.is_classmethod and orig_args and orig_args[0].arg == "cls": del self.name_remap[orig_args[0].arg]
            self.current_function_return_type = prev_ret_type
            if hasattr(self, '_cond_optional_var_type'):
                self._cond_optional_var_type.clear()
                self._cond_optional_var_type.update(saved_cond_optional)
            self._scope_stack.pop()
            self._scope_names.pop()
        self.generic_scopes.pop()
        for k in added_variance_keys + added_default_keys:
            if k in self.generic_variance: del self.generic_variance[k]
            if k in self.generic_defaults: del self.generic_defaults[k]
        if is_generator: self.output.append(f"{self._indent()}{self.coroutine_handler.active_channel}.close()"); self.coroutine_handler.exit_generator()
        if is_init:
            if self.defined_classes.get(struct_name, {}).get("is_pydantic"): self.output.append(f"{self._indent()}self.validate() or {{ return err }}")
            self.output.append(f"{self._indent()}return self"); self.in_init = prev_in_init
        self._indent_level -= 1; self.output.append(f"{self._indent()}}}")
        func_code = "\n".join(self.output)
        if is_nested: old_output.append(func_code)
        else:
            self.emitter.add_function(func_code)
            if not is_unittest_method and not is_abstract and annotations_data:
                anno_map = ", ".join([f"'{k}': '{v}'" for k, v in annotations_data.items()])
                const_name = self._to_snake_case(f"{struct_name}_{func_name}__annotations__" if is_method and struct_name else f"{func_name}__annotations__")
                self.emitter.add_constant(f"{'pub ' if pub_pfx else ''}{const_name} = {{ {anno_map} }}")
        self.output = old_output; self._indent_level = old_indent
