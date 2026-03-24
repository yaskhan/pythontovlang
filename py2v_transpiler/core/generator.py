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
        # Convert UPPER_CASE constant names to snake_case for V compliance
        import re
        match = re.match(r'^(pub\s+)?const\s+([A-Z_][A-Z0-9_]*)\s*=', const_def)
        if match:
            pub_prefix = match.group(1) or ''
            upper_name = match.group(2)
            snake_name = self._to_snake_case(upper_name)
            const_def = const_def.replace(f'{pub_prefix}const {upper_name}', f'{pub_prefix}const {snake_name}', 1)
        self.constants.append(const_def)

    def _to_snake_case(self, name: str) -> str:
        """Convert UPPER_CASE to snake_case."""
        import re
        # Simple conversion: I_IDLE -> i_idle, BUFSIZE -> bufsize
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        s2 = re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1)
        return s2.lower().replace('__', '_')

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

            for c in private_constants:
                lines.append(f"const {c}")

            for c in public_constants:
                lines.append(f"pub const {c}")

            lines.append("")

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

        # Sort and deduplicate imports - MUST BE AT THE TOP
        unique_imports = sorted(list(set(imports)))
        if unique_imports:
            for imp in unique_imports:
                lines.append(f"import {imp}")
            lines.append("")

        # Define custom Any type
        lines.append("pub struct NoneType {}\n")
        lines.append("pub fn (n NoneType) str() string {\n    return 'None'\n}\n")

        lines.append("pub struct Interpolation {")
        lines.append("pub:")
        lines.append("    value       Any")
        lines.append("    expression  string")
        lines.append("    conversion  string")
        lines.append("    format_spec string")
        lines.append("}\n")

        lines.append("pub struct Template {")
        lines.append("pub:")
        lines.append("    strings        []string")
        lines.append("    interpolations []Interpolation")
        lines.append("}\n")

        lines.append("pub fn (t Template) values() []Any {")
        lines.append("    mut res := []Any{cap: t.interpolations.len}")
        lines.append("    for i in t.interpolations {")
        lines.append("        res << i.value")
        lines.append("    }")
        lines.append("    return res")
        lines.append("}\n")

        lines.append("pub fn (t1 Template) + (t2 Template) Template {")
        lines.append("    if t1.strings.len == 0 { return t2 }")
        lines.append("    if t2.strings.len == 0 { return t1 }")
        lines.append("    mut new_strings := t1.strings[..t1.strings.len - 1].clone()")
        lines.append("    new_strings << t1.strings.last() + t2.strings[0]")
        lines.append("    if t2.strings.len > 1 {")
        lines.append("        new_strings << t2.strings[1..]")
        lines.append("    }")
        lines.append("    mut new_interpolations := t1.interpolations.clone()")
        lines.append("    new_interpolations << t2.interpolations")
        lines.append("    return Template{")
        lines.append("        strings: new_strings")
        lines.append("        interpolations: new_interpolations")
        lines.append("    }")
        lines.append("}\n")

        lines.append("pub type Any = Interpolation | NoneType | Template | []Any | []u8 | bool | f64 | i64 | int | map[string]Any | string\n")

        lines.append("pub enum PyAnnotationFormat { value forwardref string }\n")

        lines.append("pub fn py_get_type_hints[T]() map[string]string {")
        lines.append("    mut hints := map[string]string{}")
        lines.append("    $for field in T.fields {")
        lines.append("        hints[field.name] = field.typ")
        lines.append("    }")
        lines.append("    return hints")
        lines.append("}\n")

        lines.append("pub fn py_get_type_hints_generic(obj Any) map[string]string {")
        lines.append("    return map[string]string{}")
        lines.append("}\n")


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
