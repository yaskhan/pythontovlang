import ast
from typing import Any, List, Optional
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TranslatorBase

class FunctionsMixin(TranslatorBase):
    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self._visit_function_common(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self._visit_function_common(node, is_async=True)

    def _visit_function_common(self, node: Any, is_async: bool = False) -> None:
        # Check for @overload
        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Name) and decorator.id == 'overload':
                return
            if isinstance(decorator, ast.Attribute) and decorator.attr == 'overload':
                return

        # Check for @singledispatch
        for decorator in node.decorator_list:
            is_singledispatch = False
            if isinstance(decorator, ast.Name) and decorator.id == 'singledispatch':
                is_singledispatch = True
            elif isinstance(decorator, ast.Attribute) and decorator.attr == 'singledispatch':
                is_singledispatch = True

            if is_singledispatch:
                # Store the base implementation with a unique name
                base_impl_name = f"{node.name}_base"
                self.renamed_functions[node.name] = base_impl_name # Temp mapping for visit

                # Initialize registry
                self.single_dispatch_functions[node.name] = {"default": base_impl_name}

        # Check for @func.register(Type)
        register_dispatcher = None
        register_type = None

        # 'node' is guaranteed to be ast.FunctionDef or ast.AsyncFunctionDef here
        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call) and isinstance(decorator.func, ast.Attribute):
                 if decorator.func.attr == "register":
                      # func.register(Type)
                      if isinstance(decorator.func.value, ast.Name):
                          register_dispatcher = decorator.func.value.id
                          if decorator.args:
                              try:
                                   type_str = ast.unparse(decorator.args[0])
                                   register_type = map_python_type_to_v(type_str)
                              except:
                                   pass

        if register_dispatcher and register_type:
             # This is an implementation of a singledispatch function
             impl_name = f"{register_dispatcher}_{register_type}"
             if register_dispatcher in self.single_dispatch_functions:
                 self.single_dispatch_functions[register_dispatcher][register_type] = impl_name
             else:
                 # Dispatcher defined after? Or in another module? (Not supported cross-module yet)
                 pass

             # Rename this function to impl_name
             # We modify node.name temporarily
             original_name = node.name
             node.name = impl_name

        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
             is_generator = self.coroutine_handler.is_generator(original_name if 'original_name' in locals() else node.name)

        # Save current state
        old_output = self.output
        self.output = []
        self._indent_level = 0

        # Analyze decorators
        dec_info = self.decorator_processor.analyze(node, self.current_class)

        # Handle decorators comments (emit all for clarity)
        for decorator in node.decorator_list:
             dec_str = self.visit(decorator)
             self.output.append(f"// @{dec_str}")

        is_method = self.current_class is not None
        # Ensure struct_name is always a string
        struct_name: str = self.current_class if self.current_class else ""

        args_str_list: List[str] = []
        receiver_str: str = ""
        args_names: List[str] = []

        # Special handling for unittest methods: flatten to function calls
        is_unittest_method = False
        if hasattr(self, 'current_class_is_unittest') and self.current_class_is_unittest:
            if node.name.startswith("test_"):
                is_unittest_method = True
                func_name = f"{node.name}_{struct_name}"
                is_method = False
                receiver_str = ""
            elif node.name in ("setUp", "tearDown"):
                 self.output.append(f"// {node.name} method in unittest class ignored")
                 return

        if is_generator:
            # Inject channel argument
            yield_type = self.coroutine_handler.get_yield_type(node)
            args_str_list.append(f"ch chan {yield_type}")
            self.coroutine_handler.enter_generator("ch")

        args = node.args.args
        if hasattr(node.args, 'posonlyargs'):
             args = node.args.posonlyargs + args

        if hasattr(node.args, 'kwonlyargs'):
             args = args + node.args.kwonlyargs

        # Check for __new__ or other static-like methods that might have 'cls'
        is_new_method = False
        if node.name == "__new__":
             is_new_method = True
             # Rename __new__
             node.name = f"new_{struct_name}_new"
             # Remove 'cls' argument if present
             if args and args[0].arg == "cls":
                 args = args[1:]
             # Treat as static
             is_method = False
             receiver_str = ""

        if is_method and args and args[0].arg == "self":
            # Handle 'self' - it becomes the receiver in V
            # UNLESS it is static
            if not dec_info.is_static:
                # fn (s Struct) method()
                if self.current_class_generics:
                    # fn (s Struct[T]) method()
                    gen_str = f"[{', '.join(self.current_class_generics)}]"
                    receiver_str = f"({args[0].arg} {struct_name}{gen_str}) "
                else:
                    receiver_str = f"({args[0].arg} {struct_name}) "

            args = args[1:] # Remove self from arguments list
        elif is_unittest_method and args and args[0].arg == "self":
             # Remove self from unittest method args
             args = args[1:]

        for arg in args:
            arg_name = arg.arg
            args_names.append(arg_name)
            # Use annotation if available for better type mapping
            if arg.annotation:
                try:
                    type_str = ast.unparse(arg.annotation)
                    arg_type = map_python_type_to_v(type_str, self_name=struct_name or "Self")
                except Exception:
                    arg_type = self.type_inference.type_map.get(arg_name, "int")
            else:
                arg_type = self.type_inference.type_map.get(arg_name, "int")

            args_str_list.append(f"{arg_name} {arg_type}")

        if node.args.vararg:
            arg_name = node.args.vararg.arg
            arg_type = "int" # Default
            if node.args.vararg.annotation:
                try:
                    type_str = ast.unparse(node.args.vararg.annotation)
                    arg_type = map_python_type_to_v(type_str, self_name=struct_name or "Self")
                except Exception:
                    pass
            args_str_list.append(f"{arg_name} ...{arg_type}")
            args_names.append(arg_name)

        if node.args.kwarg:
            arg_name = node.args.kwarg.arg
            arg_type = "map[string]string"
            if node.args.kwarg.annotation:
                try:
                    type_str = ast.unparse(node.args.kwarg.annotation)
                    arg_type = map_python_type_to_v(type_str, self_name=struct_name or "Self")
                except Exception:
                    pass
            args_str_list.append(f"{arg_name} {arg_type}")
            args_names.append(arg_name)

        args_str = ", ".join(args_str_list)

        ret_type = "void"
        if not is_generator and node.returns:
             try:
                 type_str = ast.unparse(node.returns)
                 ret_type = map_python_type_to_v(type_str, self_name=struct_name or "Self")
             except:
                 if isinstance(node.returns, ast.Name):
                      ret_type = node.returns.id
                 elif isinstance(node.returns, ast.Constant) and isinstance(node.returns.value, str):
                      ret_type = node.returns.value

        # Check for NoReturn
        is_noreturn = False
        if ret_type == "void":
             # Check if original annotation was NoReturn
             try:
                 if hasattr(ast, 'unparse'):
                      ret_str = ast.unparse(node.returns)
                      if "NoReturn" in ret_str:
                           is_noreturn = True
             except:
                 pass

        if not is_unittest_method:
            func_name = node.name

            # Descriptor protocol renaming
            if func_name == "__get__":
                 func_name = "get"
            elif func_name == "__set__":
                 func_name = "set"
            elif func_name == "__delete__":
                 func_name = "delete"

            if self.current_class and not is_new_method:
                func_name = self._mangle_name(func_name, self.current_class)

            if func_name in self.renamed_functions:
                func_name = self.renamed_functions[func_name]

        # Handle cache wrapper generation
        if dec_info.cache_wrapper_needed and dec_info.implementation_name:
            wrapper_code = self.decorator_processor.generate_cache_wrapper(
                dec_info, func_name, args_str, ret_type, args_names, receiver_str
            )
            self.emitter.add_function(wrapper_code)

            # Switch to generating implementation
            func_name = dec_info.implementation_name

        if 'decl' not in locals() and func_name == "__init_subclass__":
            receiver_str = ""
            func_name = "init_subclass"
        elif func_name == "__init__":
            func_name = f"new_{struct_name}"
            receiver_str = "" # Factory is static
            ret_type = struct_name
            if self.current_class_generics:
                sanitized_gens = [g.lstrip('_') for g in self.current_class_generics]
                gen_str = f"[{', '.join(sanitized_gens)}]"
                func_name += gen_str
                ret_type += gen_str

        elif is_method and func_name in ("__add__", "__sub__", "__mul__", "__truediv__", "__mod__", "__lt__", "__le__", "__eq__", "__ne__"):
             # Operator overloading
             op_map = {
                 "__add__": "+", "__sub__": "-", "__mul__": "*", "__truediv__": "/",
                 "__mod__": "%", "__lt__": "<", "__le__": "<=", "__eq__": "==",
                 "__ne__": "!="
             }
             op = op_map.get(func_name)
             if op:
                 func_name = op
                 decl = f"fn {receiver_str}{op} ({args_str}) {ret_type} {{"
        elif func_name in ("__str__", "__repr__"):
             func_name = "str"
             decl = f"fn {receiver_str}{func_name}() string {{"

        noreturn_attr = "[noreturn]\n" if is_noreturn else ""

        if 'decl' not in locals():
            decl = f"{noreturn_attr}fn {receiver_str}{func_name}({args_str}) {ret_type} {{"
        if ret_type == "void":
             decl = f"{noreturn_attr}fn {receiver_str}{func_name}({args_str}) {{"

        self.output.append(f"{decl}")
        self._indent_level += 1

        for line in dec_info.injected_start:
             self.output.append(f"{self._indent()}{line}")

        for line in dec_info.injected_end:
             self.output.append(f"{self._indent()}{line}")

        for stmt in node.body:
            self.visit(stmt)

        if is_generator:
            self.output.append(f"{self._indent()}{self.coroutine_handler.active_channel}.close()")
            self.coroutine_handler.exit_generator()

        self._indent_level -= 1
        self.output.append("}")

        self.emitter.add_function("\n".join(self.output))

        self.output = old_output

    def visit_Lambda(self, node: ast.Lambda) -> str:
        # lambda args: expr -> fn (args) { return expr }
        args_str_list = []
        for arg in node.args.args:
            arg_name = arg.arg
            arg_type = "int" # Default type for now
            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)
        body = self.visit(node.body)

        return f"fn ({args_str}) int {{ return {body} }}"

    def visit_Yield(self, node: ast.Yield) -> str:
        if self.coroutine_handler.active_channel:
             val = self.visit(node.value) if node.value else "0"
             return f"{self.coroutine_handler.active_channel} <- {val}"
        val = ""
        if node.value:
            val = self.visit(node.value)
        return f"/* yield {val} */"

    def visit_YieldFrom(self, node: ast.YieldFrom) -> Optional[str]:
        if self.coroutine_handler.active_channel:
             val = self.visit(node.value)
             self.output.append(f"{self._indent()}for v in {val} {{")
             self._indent_level += 1
             self.output.append(f"{self._indent()}{self.coroutine_handler.active_channel} <- v")
             self._indent_level -= 1
             self.output.append(f"{self._indent()}}}")
             return None

        val = self.visit(node.value)
        return f"/* yield from {val} */"

    def visit_Await(self, node: ast.Await) -> str:
        val = self.visit(node.value)
        return f"/* await */ {val}"

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
