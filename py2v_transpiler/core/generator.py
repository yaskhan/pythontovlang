from typing import List

class VCodeEmitter:
    def __init__(self):
        self.imports: List[str] = []
        self.structs: List[str] = []
        self.functions: List[str] = []
        self.main_body: List[str] = []

    def add_import(self, module_name: str) -> None:
        """Adds an import to the module."""
        if module_name not in self.imports:
            self.imports.append(module_name)

    def add_struct(self, struct_def: str) -> None:
        """Adds a struct definition."""
        self.structs.append(struct_def)

    def add_function(self, func_def: str) -> None:
        """Adds a function definition."""
        self.functions.append(func_def)

    def add_main_statement(self, stmt: str) -> None:
        """Adds a statement to the main function body."""
        self.main_body.append(stmt)

    def emit(self) -> str:
        """Generates the full V source code."""
        lines = ["module main\n"]

        # Define custom Any type
        lines.append("type Any = bool | int | i64 | f64 | string | []u8")

        if self.imports:
            for imp in self.imports:
                lines.append(f"import {imp}")
            lines.append("")

        if self.structs:
            lines.extend(self.structs)
            lines.append("")

        if self.functions:
            lines.extend(self.functions)
            lines.append("")

        if self.main_body:
            lines.append("fn main() {")
            # Indent main body
            lines.extend(["    " + line for line in self.main_body])
            lines.append("}")

        return "\n".join(lines)
