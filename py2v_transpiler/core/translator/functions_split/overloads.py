import ast
import re
from typing import Any, List, Optional, Dict, Set, TYPE_CHECKING


class FunctionOverloadMixin:
    if TYPE_CHECKING:
        visit: Any
        _indent: Any
        _indent_level: int
        output: List[str]
        current_class: Optional[str]
        generic_variance: Dict[str, str]
        generic_defaults: Dict[str, str]
        type_params_map: Dict[str, List[str]]
        generic_scopes: List[Dict[str, str]]
        current_class_generics: List[str]
        type_inference: Any
        overloaded_signatures: Dict[str, List[Dict[str, Any]]]
        coroutine_handler: Any
        decorator_processor: Any
        defined_classes: Dict[str, Dict[str, Any]]
        function_names: Set[str]
        _scope_stack: List[Set[str]]
        in_init: bool
        current_function_return_type: Optional[str]
        emitter: Any
        name_remap: Dict[str, str]
        type_vars: Set[str]
        def _sanitize_name(self, name: str, is_type: bool = False) -> str: ...
        def _get_generic_map(self, generics: List[str]) -> Dict[str, str]: ...
        def _get_all_active_v_generics(self) -> List[str]: ...
        def _get_generics_with_variance_str(self, generics: List[str]) -> str: ...
        def _map_type(
            self,
            type_str: str,
            struct_name: Optional[str] = None,
            allow_union: bool = True,
            register_sum_types: bool = True,
            is_return: bool = False
        ) -> str: ...
        def _extract_implicit_generics(self, node: Any) -> List[str]: ...
        def _get_factory_name(self, class_name: str) -> str: ...
        def _mangle_name(self, name: str, class_name: Optional[str]) -> str: ...
        def _get_full_self_type(self, struct_name: Optional[str] = None) -> str: ...
        def _is_exported(self, name: str) -> bool: ...
        def _get_source_info(self, node: Optional[ast.AST] = None) -> str: ...
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
        ) -> None: ...

    def _generate_overload_variants(
        self,
        node: Any,
        struct_name: str,
        is_method: bool,
        dec_info: Any,
        is_generator: bool,
    ) -> None:
        """Generates V functions for each @overload signature using the implementation body."""
        ov_key = f"{struct_name}.{node.name}" if is_method or node.name == "__new__" else node.name

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

        all_v_generics = self._get_all_active_v_generics()
        if all_v_generics:
            func_generics_str = self._get_generics_with_variance_str(all_v_generics)

        # Check for @warnings.deprecated
        is_deprecated = False
        deprecated_message: str | None = None
        deprecated_attr = ""

        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call):
                func = self.visit(decorator.func)
                if func == "warnings.deprecated":
                    is_deprecated = True
                    if decorator.args:
                        msg = self.visit(decorator.args[0])
                        deprecated_message = msg.strip("'\"")

        if is_deprecated and deprecated_message:
            deprecated_attr = f"@[deprecated: '{deprecated_message}']\n"
        elif is_deprecated:
            deprecated_attr = "@[deprecated]\n"

        for sig in self.overloaded_signatures[ov_key]:
            old_output = self.output
            self.output = []
            old_indent = self._indent_level
            self._indent_level = 0

            args_str_list: List[str] = []
            receiver_str: str = ""
            args_names: List[str] = []

            is_init = False
            is_pydantic = False
            is_new_factory = False
            if node.name == "__init__":
                class_info = self.defined_classes.get(struct_name, {})
                is_pydantic = class_info.get("is_pydantic", False)
                if not class_info.get("has_new"):
                    is_init = True
            elif node.name == "__new__":
                is_new_factory = True

            if is_generator:
                yield_type = self.coroutine_handler.get_yield_type(node)
                args_str_list.append(f"ch_out chan {yield_type}")
                args_str_list.append(f"ch_in chan PyGeneratorInput")
                self.coroutine_handler.enter_generator("ch_out", "ch_in")

            if is_method and not dec_info.is_static and not is_init and not is_new_factory:
                # Add self
                args = node.args.args
                if hasattr(node.args, "posonlyargs"):
                    args = node.args.posonlyargs + args
                if args and (args[0].arg == "self" or args[0].arg == "cls"):
                    if args[0].arg == "self":
                        is_mutated = False
                        if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'mutability_map'):
                             mut_info = self.type_inference.mutability_map.get("self")
                             if mut_info:
                                 is_mutated = mut_info.get("is_mutated", False)

                        mut_receiver = "mut " if getattr(dec_info, 'is_setter', False) or is_init or node.name == "__init__" or is_mutated else ""
                        if self.current_class_generics:
                            gen_str = f"[{', '.join(self.current_class_generics)}]"
                            receiver_str = f"({mut_receiver}{args[0].arg} {struct_name}{gen_str}) "
                        else:
                            receiver_str = f"({mut_receiver}{args[0].arg} {struct_name}) "
                    else:
                        # 'cls' is handled as static, no receiver_str
                        pass

            # Generate mangled name based on argument types
            type_suffix_parts = []
            for arg in sig["args"]:
                arg_name = self._sanitize_name(arg["name"])
                arg_type = arg["type"]
                args_str_list.append(f"{arg_name} {arg_type}")
                args_names.append(arg_name)
                # Clean up type for name mangling
                clean_arg_type = arg_type
                for gen in all_v_generics:
                    clean_arg_type = re.sub(rf'\b{re.escape(gen)}\b', 'generic', clean_arg_type)

                clean_type = (
                    clean_arg_type.replace("?", "opt_")
                    .replace("[]", "arr_")
                    .replace("[", "_")
                    .replace("]", "")
                    .replace(".", "_")
                )
                type_suffix_parts.append(clean_type)

            args_str = ", ".join(args_str_list)
            ret_type = sig["return"]
            if ret_type == "none":
                ret_type = "void"

            if is_init or is_new_factory:
                base_func_name = self._get_factory_name(struct_name)
                ret_type = self._get_full_self_type(struct_name)
                if is_pydantic:
                    ret_type = "!" + ret_type
            else:
                base_func_name = self._sanitize_name(node.name)

                # Static/Class methods naming for overloads: Prefix with struct name
                if (dec_info.is_static or dec_info.is_classmethod):
                    base_func_name = f"{struct_name}_{base_func_name}"

                if node.name == "__init__":
                    base_func_name = "init"
                elif self.current_class and not (dec_info.is_static or dec_info.is_classmethod):
                    base_func_name = self._sanitize_name(
                        self._mangle_name(base_func_name, self.current_class)
                    )

            if type_suffix_parts:
                func_name = f"{base_func_name}_{'_'.join(type_suffix_parts)}"
            else:
                func_name = f"{base_func_name}_noargs"

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
            is_operator = False
            op_str = ""
            if is_method and node.name in op_map:
                is_operator = True
                op_str = op_map[node.name]
                func_name = op_str

            self.function_names.add(func_name)

            if type_suffix_parts:
                self.output.append(f"//##LLM@@ This function is an overloaded variant. The generated name `{func_name}` might be long or unidiomatic. Please review and refactor to use a simpler name, or consolidate using a single function with sum type arguments where appropriate.")
            elif len(func_name) > 30:
                self.output.append(f"//##LLM@@ The generated function name `{func_name}` is unusually long. Please review and refactor to use a simpler, more idiomatic V name if possible.")

            pub_prefix = ""
            is_nested = len(self._scope_stack) > 0
            if not is_nested:
                if (not is_method and self._is_exported(node.name)) or (is_method and getattr(self, 'config', None) and not func_name.startswith('_') and not is_init):
                     pub_prefix = "pub "

                # Factory function: pub if class is exported
                if is_init:
                     if self._is_exported(struct_name):
                          pub_prefix = "pub "

            if is_operator:
                if ret_type == "void":
                    decl = f"{deprecated_attr}{pub_prefix}fn {receiver_str}{op_str} ({args_str}) {{"
                else:
                    decl = f"{deprecated_attr}{pub_prefix}fn {receiver_str}{op_str} ({args_str}) {ret_type} {{"
            else:
                if node.name.startswith("__") and node.name.endswith("__") and func_name.startswith("__") and func_name.endswith("__"):
                    self.output.append(f"{self._indent()}//##LLM@@ Unmapped Python dunder method (e.g., __call__, __getitem__) detected. V handles object behavior and operator overloading differently. Please implement the equivalent V logic or refactor the calling code.")
                decl = f"{deprecated_attr}{pub_prefix}fn {receiver_str}{func_name}{func_generics_str}({args_str}) {ret_type} {{"
                if ret_type == "void":
                    decl = f"{deprecated_attr}{pub_prefix}fn {receiver_str}{func_name}{func_generics_str}({args_str}) {{"

            self.output.append(decl)
            self._indent_level += 1

            # Track current function return type for visit_Return
            prev_ret_type: Optional[str] = getattr(self, "current_function_return_type", None)
            self.current_function_return_type = ret_type

            prev_in_init = getattr(self, "in_init", False)
            if is_init:
                self.in_init = True
                class_info = self.defined_classes.get(struct_name, {})
                if class_info.get("is_pydantic"):
                    # Result type factory: strip ! from ret_type for allocation
                    alloc_type = ret_type[1:] if ret_type.startswith("!") else ret_type
                    self.output.append(f"{self._indent()}mut self := {alloc_type}{{}}")
                else:
                    self.output.append(f"{self._indent()}mut self := {ret_type}{{}}")

            # Handle classmethod for overloads: map 'cls' in scope
            is_cls_method = False
            for decorator in node.decorator_list:
                dec_name = self.decorator_processor.get_decorator_name(decorator)
                if dec_name in ("classmethod", "abstractclassmethod"):
                    is_cls_method = True
                    break

            if is_cls_method:
                self.name_remap["cls"] = self._get_full_self_type(struct_name)

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

                for stmt in body:
                    self.visit(stmt)
            finally:
                if is_cls_method:
                    del self.name_remap["cls"]
                self.current_function_return_type = prev_ret_type
                if is_init:
                    class_info = self.defined_classes.get(struct_name, {})
                    if class_info.get("is_pydantic"):
                        self.output.append(f"{self._indent()}self.validate() or {{ return err }}")
                    self.output.append(f"{self._indent()}return self")
                    self.in_init = prev_in_init

            if is_generator:
                self.output.append(
                    f"{self._indent()}{self.coroutine_handler.active_channel}.close()"
                )
                self.coroutine_handler.exit_generator()

            self._indent_level -= 1
            self.output.append("}")

            self.emitter.add_function("\n".join(self.output))
            self.output = old_output
            self._indent_level = old_indent

        # Pop function generic scope
        self.generic_scopes.pop()

        # Clean up variance and defaults scope
        for k in added_variance_keys:
            if k in self.generic_variance:
                del self.generic_variance[k]
        for k in added_default_keys:
            if k in self.generic_defaults:
                del self.generic_defaults[k]
