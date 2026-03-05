import ast
from typing import Any, List, Optional

from .field_processor import PydanticFieldProcessor, PydanticFieldInfo
from .config_processor import PydanticConfigProcessor, PydanticConfigInfo
from .detector import PydanticDetector

class PydanticModelProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor
        self.field_processor = PydanticFieldProcessor(visitor)
        self.config_processor = PydanticConfigProcessor(visitor)

    def process_model(self, node: ast.ClassDef) -> str:
        """Generates a Vlang struct from a Pydantic BaseModel."""
        struct_name = self.visitor._sanitize_name(node.name)
        fields: List[PydanticFieldInfo] = []
        config: Optional[PydanticConfigInfo] = None

        # We need to collect fields and methods
        methods = []
        for item in node.body:
            if isinstance(item, ast.AnnAssign):
                info = self.field_processor.extract(item)
                fields.append(info)
            elif isinstance(item, ast.FunctionDef):
                # Will handle validators in validator_processor
                methods.append(item)
            elif PydanticDetector.is_config_class(item):
                config = self.config_processor.extract(item)

        # Generate Struct
        export = "pub " if self.visitor._is_exported(struct_name) else ""

        config_comment = ""
        if config:
            opts = []
            if config.str_strip_whitespace: opts.append("str_strip_whitespace=true")
            if config.str_to_lower: opts.append("str_to_lower=true")
            if config.str_to_upper: opts.append("str_to_upper=true")
            if config.extra != 'ignore': opts.append(f"extra={config.extra}")
            if not config.allow_mutation: opts.append("allow_mutation=false")
            if config.validate_assignment: opts.append("validate_assignment=true")
            if opts:
                config_comment = f"// Config: {', '.join(opts)}"

        struct_def = []
        if config_comment:
            struct_def.append(config_comment)

        struct_def.extend([
            f"// Pydantic Model: {struct_name}",
            "@[params]",
            f"{export}struct {struct_name} {{"
        ])

        if export:
            if config and not config.allow_mutation:
                struct_def.append("pub:")
            else:
                struct_def.append("pub mut:")
        else:
            if config and not config.allow_mutation:
                pass # default is private, immutable
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
        validation_code = self._generate_validate_method(struct_name, fields, export, config)
        if validation_code:
            self.visitor.emitter.add_function(validation_code)

        # We also need to visit methods, if any. We let the normal visitor handle methods,
        # but we pretend we are in this class.
        self.visitor.current_class = struct_name
        for method in methods:
            self.visitor.visit(method)
        self.visitor.current_class = None

        return "" # The emitter handles the actual output

    def _generate_validate_method(self, struct_name: str, fields: List[PydanticFieldInfo], export: str, config: Optional[PydanticConfigInfo]) -> str:
        """Generates a .validate() method for the struct."""
        code = [
            f"{export}fn (mut m {struct_name}) validate() ! {{",
        ]

        has_validation = False

        # Apply Config transformations
        if config:
            for field in fields:
                if field.type_str == "string":
                    if config.str_strip_whitespace:
                        code.append(f"    m.{field.name} = m.{field.name}.trim()")
                        has_validation = True
                    if config.str_to_lower:
                        code.append(f"    m.{field.name} = m.{field.name}.to_lower()")
                        has_validation = True
                    if config.str_to_upper:
                        code.append(f"    m.{field.name} = m.{field.name}.to_upper()")
                        has_validation = True

                    if config.min_anystr_length is not None:
                        code.append(f'    if m.{field.name}.len < {config.min_anystr_length} {{ return error("Validation Error: {field.name} length must be >= {config.min_anystr_length}") }}')
                        has_validation = True
                    if config.max_anystr_length is not None:
                        code.append(f'    if m.{field.name}.len > {config.max_anystr_length} {{ return error("Validation Error: {field.name} length must be <= {config.max_anystr_length}") }}')
                        has_validation = True

        for field in fields:
            vcode = self.field_processor.generate_validation_code(field, "m")
            if vcode:
                has_validation = True
                code.extend(vcode)

        if not has_validation and not (config and config.validate_all):
            return ""

        code.append("}")
        return "\n".join(code)
