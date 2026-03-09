from typing import List

class VCodeEmitter:
    def __init__(self, module_name: str = "main"):
        self.module_name = module_name
        self.imports: List[str] = []
        self.structs: List[str] = []
        self.functions: List[str] = []
        self.main_body: List[str] = []
        self.init_body: List[str] = []
        self.globals: List[str] = []
        self.constants: List[str] = []

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

    def add_global(self, global_def: str) -> None:
        """Adds a __global definition."""
        self.globals.append(global_def)

    def add_constant(self, const_def: str) -> None:
        """Adds a const definition."""
        self.constants.append(const_def)

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

    def add_init_statement(self, stmt: str) -> None:
        """Adds a statement to the init function body."""
        self.init_body.append(stmt)

    def add_main_statement(self, stmt: str) -> None:
        """Adds a statement to the main function body."""
        self.main_body.append(stmt)

    def emit(self) -> str:
        """Generates the full V source code."""
        lines = [f"module {self.module_name}\n"]

        if self.imports:
            for imp in self.imports:
                lines.append(f"import {imp}")
            lines.append("")

        if self.structs:
            lines.extend(self.structs)
            lines.append("")

        if self.globals:
            lines.insert(1, "// To compile with globals, use: v -enable-globals .")
            for g in self.globals:
                sanitized_g = g
                if g.startswith("pub "):
                    sanitized_g = g[4:]
                lines.append(f"__global {sanitized_g}")
            lines.append("")

        if self.constants:
            public_constants = [c[4:] for c in self.constants if c.startswith("pub ")]
            private_constants = [c for c in self.constants if not c.startswith("pub ")]

            if private_constants:
                lines.append("const (")
                lines.extend(["    " + c for c in private_constants])
                lines.append(")\n")

            if public_constants:
                lines.append("pub const (")
                lines.extend(["    " + c for c in public_constants])
                lines.append(")\n")

        if self.functions:
            lines.extend(self.functions)
            lines.append("")

        if self.init_body:
            lines.append("fn init() {")
            lines.extend(["    " + line for line in self.init_body])
            lines.append("}\n")

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
    def emit_global_helpers(imports: List[str], structs: List[str], functions: List[str], module_name: str = "main") -> str:
        """Generates the V source code for an aggregated set of helpers."""
        lines = [f"module {module_name}\n"]

        # Define custom Any type
        lines.append("// Base sum type (no none)")
        lines.append("pub type AnyValue = bool | int | i64 | f64 | string | []u8 | map[string]?AnyValue | []?AnyValue\n")
        lines.append("// Optional wrapper for None support")
        lines.append("pub type Any = ?AnyValue\n")

        lines.append("// Helper functions")
        lines.append("pub fn Any_none() Any { return none }")
        lines.append("pub fn Any_some(v AnyValue) Any { return v }\n")

        lines.append("// Type check helpers")
        lines.append("pub fn Any_is_int(x Any) bool { if v := x { return v is int } return false }")
        lines.append("pub fn Any_is_string(x Any) bool { if v := x { return v is string } return false }\n")

        lines.append("// Type extraction helpers")
        lines.append("pub fn Any_as_int(x Any) int { if v := x { if v is int { return v } } return 0 }")
        lines.append("pub fn Any_as_string(x Any) string { if v := x { if v is string { return v } } return '' }\n")

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
