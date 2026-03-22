import ast
from typing import Optional, List, Set, Any, TYPE_CHECKING
from ..base import TranslatorBase


class OtherFunctionVisitorsMixin(TranslatorBase):
    if TYPE_CHECKING:
        def _find_captured_vars(self, node: ast.AST) -> List[str]: ...
        _scope_stack: List[Set[str]]
        _scope_names: List[str]
        type_inference: Any
        def _map_type(self, type_str: str, struct_name: Optional[str] = None, allow_union: bool = True, register_sum_types: bool = True, is_return: bool = False) -> str: ...

    def visit_Lambda(self, node: ast.Lambda) -> str:
        # lambda args: expr -> fn [captures] (args) { return expr }

        # Build defaults_map to detect the i=i capture-by-value pattern.
        # In Python, `lambda x, i=i: x + i` uses a default arg to capture i
        # by value at definition time. In V this becomes a closure capture [i].
        #
        # IMPORTANT: arguments.defaults covers the LAST N args of the combined
        # posonlyargs + args list, not just args. Use the combined list here.
        defaults_map: dict[str, ast.expr] = {}
        if node.args.defaults:
            posonly = list(getattr(node.args, 'posonlyargs', []))
            positional = posonly + list(node.args.args)
            defaults_start = len(positional) - len(node.args.defaults)
            for idx, default in enumerate(node.args.defaults):
                defaults_map[positional[defaults_start + idx].arg] = default

        # Prepare arguments string and collect them for the scope
        current_scope: Set[str] = set()
        args_str_list = []
        # extra_captures holds args that use the i=i pattern; they become [i]
        # closure captures in V instead of regular parameters.
        extra_captures: List[str] = []

        all_args = node.args.args
        if hasattr(node.args, 'posonlyargs'):
            all_args = node.args.posonlyargs + all_args
        if hasattr(node.args, 'kwonlyargs'):
            all_args = all_args + node.args.kwonlyargs

        for arg in all_args:
            arg_name = self._sanitize_name(arg.arg)

            # Detect i=i pattern: default is ast.Name whose id matches arg name
            default_expr = defaults_map.get(arg.arg)
            if (isinstance(default_expr, ast.Name)
                    and default_expr.id == arg.arg):
                extra_captures.append(arg_name)
                continue

            current_scope.add(arg.arg)
            # Try to get inferred type
            arg_type = "int"
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'type_map'):
                inferred = self.type_inference.type_map.get(arg_name)
                if inferred:
                    arg_type = self._map_type(inferred)
            args_str_list.append(f"{arg_name} {arg_type}")

        # V requires variadic parameter (...args) to be the final parameter.
        # If both *args and **kwargs are present, we must swap them or warn.
        if node.args.vararg and node.args.kwarg:
            self.output.append(f"{self._indent()}//##LLM@@ Lambda has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls accordingly.")

        # Add kwarg before vararg to ensure variadic is last if both exist
        if node.args.kwarg:
            arg_name = self._sanitize_name(node.args.kwarg.arg)
            current_scope.add(node.args.kwarg.arg)
            arg_type = "map[string]Any"
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'type_map'):
                inferred = self.type_inference.type_map.get(arg_name)
                if inferred:
                    arg_type = self._map_type(inferred)
            args_str_list.append(f"{arg_name} {arg_type}")

        if node.args.vararg:
            arg_name = self._sanitize_name(node.args.vararg.arg)
            current_scope.add(node.args.vararg.arg)
            arg_type = "Any"
            if hasattr(self, 'type_inference') and hasattr(self.type_inference, 'type_map'):
                inferred = self.type_inference.type_map.get(arg_name)
                if inferred:
                    arg_type = self._map_type(inferred)

            # Lambdas are closures in V, and V closures do not support variadic parameters.
            # We use a slice instead.
            if not arg_type.startswith("[]"):
                arg_type = f"[]{arg_type}"
            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)

        # Find captures BEFORE pushing current lambda's scope
        captures = self._find_captured_vars(node)

        # Merge i=i-pattern captures (not seen by _find_captured_vars because
        # those args are listed in node.args and treated as inner_defs there).
        if extra_captures:
            existing = set(captures)
            for name in extra_captures:
                if name not in existing:
                    captures.append(name)
                    existing.add(name)

        capture_str = f"[{', '.join(captures)}] " if captures else ""

        if isinstance(node.body, ast.Constant) and node.body.value is None:
             # Force void return for lambda x: None
             return f"fn {capture_str}({args_str}) {{}}"

        # Push scope for visiting body
        self._scope_stack.append(current_scope)
        self._scope_names.append("<lambda>")

        try:
            body = self.visit(node.body)
            body_type = self._map_type(self._guess_type(node.body), is_return=True)

            if body_type == "void":
                if body == "none":
                    return f"fn {capture_str}({args_str}) {{}}"
                return f"fn {capture_str}({args_str}) {{ {body} }}"

            return f"fn {capture_str}({args_str}) {body_type} {{ return {body} }}"
        finally:
            self._scope_stack.pop()
            self._scope_names.pop()

    def visit_Yield(self, node: ast.Yield) -> str:
        if self.coroutine_handler.active_channel:
            val = self.visit(node.value) if node.value else "0"
            return f"py_yield({self.coroutine_handler.active_channel}, {self.coroutine_handler.active_in_channel}, {val})"
        val = ""
        if node.value:
            val = self.visit(node.value)
        return f"/* yield {val} */"

    def visit_YieldFrom(self, node: ast.YieldFrom) -> Optional[str]:
        if self.coroutine_handler.active_channel:
            val = self.visit(node.value)
            self.output.append(f"{self._indent()}for v in {val} {{")
            self._indent_level += 1
            self.output.append(
                f"{self._indent()}py_yield({self.coroutine_handler.active_channel}, {self.coroutine_handler.active_in_channel}, v)"
            )
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
        self.output.append(f"{self._indent()}//##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.")
        self.output.append(f"{self._indent()}// global {names}")

    def visit_Nonlocal(self, node: ast.Nonlocal) -> None:
        names = ", ".join(node.names)
        self.output.append(f"{self._indent()}//##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.")
        self.output.append(f"{self._indent()}// nonlocal {names}")

    def visit_Return(self, node: ast.Return) -> None:
        if self.coroutine_handler.active_channel:
            self.output.append(
                f"{self._indent()}{self.coroutine_handler.active_channel}.close()"
            )

        for _ in range(self.vexc_depth):
            self.output.append(f"{self._indent()}vexc.end_try()")

        if getattr(self, "in_init", False) and not node.value:
            current_class = self.current_class or ""
            class_info = self.defined_classes.get(current_class, {})
            if class_info.get("is_pydantic"):
                self.output.append(f"{self._indent()}self.validate() or {{ return err }}")
            self.output.append(f"{self._indent()}return self")
        elif node.value:
            prev_assign_type = self.current_assignment_type
            self.current_assignment_type = self.current_function_return_type

            try:
                val = self.visit(node.value)
            finally:
                self.current_assignment_type = prev_assign_type

            if self.current_function_return_type == "void" and val == "none":
                self.output.append(f"{self._indent()}return")
            else:
                self.output.append(f"{self._indent()}return {val}")
        else:
            self.output.append(f"{self._indent()}return")
