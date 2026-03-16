import ast
from typing import Optional, List, TYPE_CHECKING
from ..base import TranslatorBase


class OtherFunctionVisitorsMixin(TranslatorBase):
    if TYPE_CHECKING:
        def _find_captured_vars(self, node: ast.AST) -> List[str]: ...

    def visit_Lambda(self, node: ast.Lambda) -> str:
        # lambda args: expr -> fn [captures] (args) { return expr }
        if isinstance(node.body, ast.Constant) and node.body.value is None:
             # Force void return for lambda x: None
             args_str_list = []
             for arg in node.args.args:
                 arg_name = self._sanitize_name(arg.arg)
                 arg_type = "int"
                 args_str_list.append(f"{arg_name} {arg_type}")
             args_str = ", ".join(args_str_list)
             captures = self._find_captured_vars(node)
             capture_str = f"[{', '.join(captures)}] " if captures else ""
             return f"fn {capture_str}({args_str}) {{}}"

        args_str_list = []
        for arg in node.args.args:
            arg_name = self._sanitize_name(arg.arg)
            arg_type = "int"  # Default type for now
            args_str_list.append(f"{arg_name} {arg_type}")

        args_str = ", ".join(args_str_list)

        captures = self._find_captured_vars(node)
        capture_str = f"[{', '.join(captures)}] " if captures else ""

        body = self.visit(node.body)
        body_type = self._map_type(self._guess_type(node.body), is_return=True)

        if body_type == "void":
            if body == "none":
                return f"fn {capture_str}({args_str}) {{}}"
            return f"fn {capture_str}({args_str}) {{ {body} }}"

        return f"fn {capture_str}({args_str}) {body_type} {{ return {body} }}"

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
