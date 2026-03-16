import ast
from typing import Any, Dict
from ..base import TranslatorBase


class FunctionVisitorMixin(TranslatorBase):
    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self._visit_function_common(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self._visit_function_common(node, is_async=True)

    def _visit_function_common(self, node: Any, is_async: bool = False) -> None:
        # Clear name remaps at function start to avoid leakage from other functions
        self.name_remap.clear()

        # Check for @overload
        is_overload = False
        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Name) and decorator.id == "overload":
                is_overload = True
                break
            if isinstance(decorator, ast.Attribute) and decorator.attr == "overload":
                is_overload = True
                break

        if is_overload:
            sig: Dict[str, Any] = {"args": [], "return": "void"}
            ov_struct_name = self.current_class if self.current_class else ""

            args = node.args.args
            if hasattr(node.args, "posonlyargs"):
                args = node.args.posonlyargs + args
            if hasattr(node.args, "kwonlyargs"):
                args = args + node.args.kwonlyargs

            is_method = self.current_class is not None
            is_cls_method = False
            for decorator in node.decorator_list:
                dec_name = self.decorator_processor.get_decorator_name(decorator)
                if dec_name in ("classmethod", "abstractclassmethod"):
                    is_cls_method = True
                    break

            if is_method and args and (args[0].arg == "self" or is_cls_method or (node.name == "__new__" and args[0].arg == "cls")):
                args = args[1:]

            for arg in args:
                arg_name = self._sanitize_name(arg.arg)
                if arg.annotation:
                    try:
                        type_str = ast.unparse(arg.annotation)
                        self._check_experimental_type(type_str, arg.annotation)
                        arg_type = self._map_type(type_str, ov_struct_name)
                    except Exception:
                        arg_type = self._map_type(self.type_inference.type_map.get(arg_name, "int"), ov_struct_name)
                else:
                    arg_type = self._map_type(self.type_inference.type_map.get(arg_name, "int"), ov_struct_name)
                sig["args"].append({"name": arg_name, "type": arg_type})

            if node.returns:
                try:
                    type_str = ast.unparse(node.returns)
                    self._check_experimental_type(type_str, node.returns)
                    sig["return"] = self._map_type(type_str, ov_struct_name, is_return=True)
                except:
                    if isinstance(node.returns, ast.Name):
                        sig["return"] = self._map_type(node.returns.id, ov_struct_name, is_return=True)
                    elif isinstance(node.returns, ast.Constant) and isinstance(
                        node.returns.value, str
                    ):
                        sig["return"] = self._map_type(node.returns.value, ov_struct_name, is_return=True)

            ov_key = f"{ov_struct_name}.{node.name}" if ov_struct_name else node.name
            if ov_key not in self.overloaded_signatures:
                self.overloaded_signatures[ov_key] = []
            self.overloaded_signatures[ov_key].append(sig)
            return

        # Check for @singledispatch
        for decorator in node.decorator_list:
            is_singledispatch = False
            if isinstance(decorator, ast.Name) and decorator.id == "singledispatch":
                is_singledispatch = True
            elif (
                isinstance(decorator, ast.Attribute)
                and decorator.attr == "singledispatch"
            ):
                is_singledispatch = True

            if is_singledispatch:
                base_impl_name = f"{node.name}_base"
                self.renamed_functions[node.name] = (
                    base_impl_name  # Temp mapping for visit
                )
                self.single_dispatch_functions[node.name] = {"default": base_impl_name}

        # Check for @func.register(Type)
        register_dispatcher = None
        register_type = None

        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call) and isinstance(
                decorator.func, ast.Attribute
            ):
                if decorator.func.attr == "register":
                    if isinstance(decorator.func.value, ast.Name):
                        register_dispatcher = decorator.func.value.id
                        if decorator.args:
                            try:
                                type_str = ast.unparse(decorator.args[0])
                                register_type = self._map_type(type_str)
                            except:
                                pass

        if register_dispatcher and register_type:
            impl_name = f"{register_dispatcher}_{register_type}"
            if register_dispatcher in self.single_dispatch_functions:
                self.single_dispatch_functions[register_dispatcher][
                    register_type
                ] = impl_name

            setattr(node, "original_name", node.name)
            node.name = impl_name

        is_abstract = False
        for decorator in node.decorator_list:
            if (
                isinstance(decorator, ast.Name) and decorator.id == "abstractmethod"
            ) or (
                isinstance(decorator, ast.Attribute)
                and decorator.attr == "abstractmethod"
            ):
                is_abstract = True
                break

        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            func_lookup_name = getattr(node, "original_name", node.name)
            is_generator = self.coroutine_handler.is_generator(func_lookup_name)

        dec_info = self.decorator_processor.analyze(node, self.current_class)

        is_method = self.current_class is not None
        base_struct_name: str = self.current_class if self.current_class else ""

        is_mixin = False
        struct_names = [base_struct_name]
        if is_method and hasattr(self.type_inference, "mixin_to_main"):
            if base_struct_name in self.type_inference.mixin_to_main:
                struct_names = self.type_inference.mixin_to_main[base_struct_name]
                is_mixin = True

        is_nested = len(self._scope_stack) > 0

        if is_nested:
            has_generics = hasattr(node, "type_params") and node.type_params
            if has_generics:
                 all_v = self._get_all_active_v_generics()
                 if all_v: has_generics = True

            if has_generics:
                self._generate_function_for_struct(
                    node,
                    is_async,
                    is_method,
                    "",
                    dec_info,
                    is_generator,
                    is_abstract,
                    force_standalone=True
                )
            else:
                self._generate_function_for_struct(
                    node,
                    is_async,
                    is_method,
                    "",
                    dec_info,
                    is_generator,
                    is_abstract,
                )
        else:
            old_output = self.output
            for struct_name in struct_names:
                self._generate_function_for_struct(
                    node,
                    is_async,
                    is_method,
                    struct_name,
                    dec_info,
                    is_generator,
                    is_abstract,
                )
            self.output = old_output
