"""Handling print() and input()."""

import ast
from typing import TYPE_CHECKING, Any


class PrintCallsMixin:
    """Mixin for handling print calls."""

    if TYPE_CHECKING:
        def visit(self, node: ast.AST) -> str: ...
        emitter: Any

    def _handle_print_call(self, node: ast.Call, args: list) -> str | None:
        """Handle print() with support for sep, end, and file."""

        sep = " "
        end = "\\n"
        is_stderr = False

        for keyword in node.keywords:
            if keyword.arg == "sep":
                if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                    sep = keyword.value.value
            elif keyword.arg == "end":
                if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                    end = keyword.value.value
                    if end == "\n":
                        end = "\\n"
            elif keyword.arg == "file":
                file_val = self.visit(keyword.value)
                if file_val == "sys.stderr":
                    is_stderr = True

        parts = []
        for arg in node.args:
            val = self.visit(arg)
            val_str = str(val)
            if val_str.startswith("'") and val_str.endswith("'"):
                parts.append(val_str[1:-1])
            else:
                parts.append(f"${{{val_str}}}")

        joined_content = sep.join(parts)

        if is_stderr:
            if end == "\\n":
                return f"eprintln('{joined_content}')"
            elif end == "":
                return f"eprint('{joined_content}')"
            else:
                return f"eprint('{joined_content}{end}')"
        else:
            if end == "\\n":
                return f"println('{joined_content}')"
            elif end == "":
                return f"print('{joined_content}')"
            else:
                return f"print('{joined_content}{end}')"

    def _handle_input_call(self, node: ast.Call, args: list) -> str | None:
        """Handle input()."""

        self.emitter.add_import("os")

        if args:
            return f"os.input({args[0]})"
        return "os.input('')"
