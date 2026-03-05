import ast
from typing import Any, List

from .field_processor import PydanticFieldProcessor, PydanticFieldInfo

class PydanticModelProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor
        self.field_processor = PydanticFieldProcessor(visitor)

    def process_model(self, node: ast.ClassDef) -> str:
        """Generates a Vlang struct from a Pydantic BaseModel."""
        struct_name = self.visitor._sanitize_name(node.name)
        fields: List[PydanticFieldInfo] = []

        # We need to collect fields and methods
        methods = []
        for item in node.body:
            if isinstance(item, ast.AnnAssign):
                info = self.field_processor.extract(item)
                fields.append(info)
            elif isinstance(item, ast.FunctionDef):
                # Will handle validators in validator_processor
                methods.append(item)

        # Check if we need to add imports
        for field in fields:
            if field.pattern:
                self.visitor.emitter.add_import("regex")
                break

        # Generate Struct
        export = "pub " if self.visitor._is_exported(struct_name) else ""

        struct_def = [
            f"// Pydantic Model: {struct_name}",
            "@[params]",
            f"{export}struct {struct_name} {{"
        ]

        if export:
             struct_def.append("pub mut:")
        else:
             struct_def.append("mut:")

        for field in fields:
            tag = self.field_processor.generate_struct_tags(field)
            default = f" = {field.default_val}" if field.default_val else ""

            # V syntax: field type [tag]
            line = f"    {field.name} {field.type_str}"
            if tag:
                 line += f" {tag}"
            if default:
                 line += default

            struct_def.append(line)

        struct_def.append("}")

        # Register the class in translator so it knows it exists
        self.visitor.defined_classes[struct_name] = {"has_init": False, "has_new": False}
        self.visitor.emitter.add_struct("\n".join(struct_def))

        # Generate Validation Method
        validation_code = self._generate_validate_method(struct_name, fields, export)
        if validation_code:
            self.visitor.emitter.add_function(validation_code)

        # We also need to visit methods, if any. We let the normal visitor handle methods,
        # but we pretend we are in this class.
        self.visitor.current_class = struct_name
        for method in methods:
            self.visitor.visit(method)
        self.visitor.current_class = None

        return "" # The emitter handles the actual output

    def _generate_validate_method(self, struct_name: str, fields: List[PydanticFieldInfo], export: str) -> str:
        """Generates a .validate() method for the struct."""
        code = [
            f"{export}fn (mut m {struct_name}) validate() ! {{",
        ]

        has_validation = False
        for field in fields:
            vcode = self.field_processor.generate_validation_code(field, "m")
            if vcode:
                has_validation = True
                code.extend(vcode)

        if not has_validation:
            return ""

        code.append("}")
        return "\n".join(code)
