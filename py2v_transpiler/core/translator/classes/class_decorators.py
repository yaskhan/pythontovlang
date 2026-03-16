"""Handler for class decorators."""

import ast
from typing import List, Optional, Tuple


class ClassDecoratorHandler:
    """Handles processing of class decorators."""

    def __init__(self, translator):
        self.translator = translator

    def process_decorators(self, node: ast.ClassDef) -> Tuple[List[str], bool, bool, bool, Optional[str]]:
        """
        Process class decorators and return decorator information.

        Returns:
            Tuple of (decorators list, is_dataclass, is_deprecated, is_disjoint_base, deprecated_message)
        """
        decorators = []
        is_dataclass = False
        is_deprecated = False
        is_disjoint_base = False
        deprecated_message: Optional[str] = None

        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call):
                # Decorator with args: @dec(arg)
                func = self.translator.visit(decorator.func)
                dec_args_list = []
                for dec_arg in decorator.args:
                    dec_args_list.append(str(self.translator.visit(dec_arg)))
                for kw in decorator.keywords:
                    val = self.translator.visit(kw.value)
                    dec_args_list.append(f"{kw.arg}={val}")
                dec_str = f"{func}({', '.join(dec_args_list)})"

                # Check for @deprecated("message")
                if (
                    func == "deprecated" or func == "warnings.deprecated"
                ) and dec_args_list:
                    is_deprecated = True
                    # Extract message from first positional argument
                    msg = dec_args_list[0].strip("'\"")
                    deprecated_message = msg
            else:
                dec_str = self.translator.visit(decorator)
                # Check for @deprecated without args (rare but possible)
                if dec_str == "deprecated":
                    is_deprecated = True
                elif dec_str in ("disjoint_base", "typing.disjoint_base"):
                    is_disjoint_base = True

            decorators.append(f"// @{dec_str}")
            if dec_str.startswith("dataclass") or dec_str.startswith(
                "dataclasses.dataclass"
            ):
                is_dataclass = True

        return decorators, is_dataclass, is_deprecated, is_disjoint_base, deprecated_message

    def process_metaclass(self, node: ast.ClassDef) -> List[str]:
        """Process metaclass and return decorator comments."""
        decorators = []
        for keyword in node.keywords:
            if keyword.arg == "metaclass":
                meta_val = self.translator.visit(keyword.value)
                decorators.append(f"// Metaclass: {meta_val}")
        return decorators
