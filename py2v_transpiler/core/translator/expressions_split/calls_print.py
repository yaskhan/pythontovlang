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

        sep_val: str | None = " "
        end_val: str | None = "\n"
        is_stderr = False

        sep_expr = "' '"
        end_expr = "'\\n'"

        for keyword in node.keywords:
            if keyword.arg == "sep":
                sep_expr = self.visit(keyword.value)
                if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                    sep_val = keyword.value.value
                else:
                    sep_val = None
            elif keyword.arg == "end":
                end_expr = self.visit(keyword.value)
                if isinstance(keyword.value, ast.Constant) and isinstance(keyword.value.value, str):
                    end_val = keyword.value.value
                else:
                    end_val = None
            elif keyword.arg == "file":
                file_val = self.visit(keyword.value)
                if file_val in ("sys.stderr", "os.stderr"):
                    is_stderr = True

        def escape_v(s):
            return s.replace('\\', '\\\\').replace('\'', '\\\'').replace('\t', '\\t').replace('\n', '\\n').replace('\r', '\\r')

        parts = []
        for arg in node.args:
            val = self.visit(arg)
            val_str = str(val)
            if val_str.startswith("'") and val_str.endswith("'"):
                parts.append(('literal', val_str[1:-1]))
            else:
                parts.append(('expr', val_str))

        if sep_val is not None:
            joined_content = ""
            esc_sep = escape_v(sep_val)
            for i, (kind, val) in enumerate(parts):
                if i > 0:
                    joined_content += esc_sep
                if kind == 'literal':
                    joined_content += val
                else:
                    joined_content += f"${{{val}}}"
        else:
            v_elements = []
            for kind, val in parts:
                if kind == 'literal':
                    v_elements.append(f"'{val}'")
                else:
                    v_elements.append(f"({val}).str()")
            joined_content = f"${{[{', '.join(v_elements)}].join({sep_expr})}}"

        if is_stderr:
            func = "eprintln" if end_val == "\n" else "eprint"
        else:
            func = "println" if end_val == "\n" else "print"

        if end_val == "\n":
            return f"{func}('{joined_content}')"
        elif end_val == "":
            return f"{func}('{joined_content}')"
        elif end_val is not None:
            esc_end = escape_v(end_val)
            return f"{func}('{joined_content}{esc_end}')"
        else:
            return f"{func}('{joined_content}${{{end_expr}}}')"

    def _handle_input_call(self, node: ast.Call, args: list) -> str | None:
        """Handle input()."""

        self.emitter.add_import("os")

        if args:
            return f"os.input({args[0]})"
        return "os.input('')"
