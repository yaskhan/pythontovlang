from typing import List

class VCodeEmitter:
    def __init__(self):
        self.imports: List[str] = []
        self.structs: List[str] = []
        self.functions: List[str] = []
        self.main_body: List[str] = []

        self.helper_imports: List[str] = []
        self.helper_structs: List[str] = []
        self.helper_functions: List[str] = []

    def get_helper_imports(self) -> List[str]:
        return self.helper_imports

    def get_helper_structs(self) -> List[str]:
        return self.helper_structs

    def get_helper_functions(self) -> List[str]:
        return self.helper_functions

    def add_import(self, module_name: str) -> None:
        """Adds an import to the module."""
        if module_name not in self.imports:
            self.imports.append(module_name)

    def add_helper_import(self, module_name: str) -> None:
        """Adds an import to the helpers module."""
        if module_name not in self.helper_imports:
            self.helper_imports.append(module_name)

    def add_struct(self, struct_def: str) -> None:
        """Adds a struct definition."""
        self.structs.append(struct_def)

    def add_helper_struct(self, struct_def: str) -> None:
        """Adds a struct definition to helpers."""
        self.helper_structs.append(struct_def)

    def add_function(self, func_def: str) -> None:
        """Adds a function definition."""
        self.functions.append(func_def)

    def add_helper_function(self, func_def: str) -> None:
        """Adds a function definition to helpers."""
        self.helper_functions.append(func_def)

    def add_main_statement(self, stmt: str) -> None:
        """Adds a statement to the main function body."""
        self.main_body.append(stmt)

    def emit(self) -> str:
        """Generates the full V source code."""
        lines = ["module main\n"]

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

    def emit_helpers(self) -> str:
        """Generates the V source code for helpers."""
        return VCodeEmitter.emit_global_helpers(
            self.helper_imports,
            self.helper_structs,
            self.helper_functions
        )

    @staticmethod
    def emit_global_helpers(imports: List[str], structs: List[str], functions: List[str]) -> str:
        """Generates the V source code for an aggregated set of helpers."""
        lines = ["module main\n"]

        # Define custom Any type
        lines.append("type Any = bool | int | i64 | f64 | string | []u8\n")

        # Sort and deduplicate imports
        unique_imports = sorted(list(set(imports)))
        if unique_imports:
            for imp in unique_imports:
                lines.append(f"import {imp}")
            lines.append("")

        # Deduplicate structs (preserving order roughly)
        seen_structs = set()
        unique_structs = []
        for s in structs:
            if s not in seen_structs:
                seen_structs.add(s)
                unique_structs.append(s)

        if unique_structs:
            lines.extend(unique_structs)
            lines.append("")

        # Deduplicate functions
        seen_funcs = set()
        unique_funcs = []
        for f in functions:
            if f not in seen_funcs:
                seen_funcs.add(f)
                unique_funcs.append(f)

        if unique_funcs:
            lines.extend(unique_funcs)
            lines.append("")

        return "\n".join(lines)
