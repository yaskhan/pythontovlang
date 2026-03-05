import ast
from typing import Any, List, Dict, Optional

from .field_processor import PydanticFieldProcessor, PydanticFieldInfo
from .validator_processor import PydanticValidatorProcessor, PydanticValidatorInfo
from .config_processor import PydanticConfigProcessor, PydanticConfigInfo
from .detector import PydanticDetector

class PydanticModelProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor
        self.field_processor = PydanticFieldProcessor(visitor)
        self.validator_processor = PydanticValidatorProcessor(visitor)
        self.config_processor = PydanticConfigProcessor(visitor)

    def process_model(self, node: ast.ClassDef) -> str:
        """Generates a Vlang struct from a Pydantic BaseModel."""
        struct_name = self.visitor._sanitize_name(node.name)
        fields: List[PydanticFieldInfo] = []
        methods = []
        validators: List[PydanticValidatorInfo] = []
        config: Optional[PydanticConfigInfo] = None
        configs: Dict[str, str] = {}

        # We need to collect fields and methods
        for item in node.body:
            if isinstance(item, ast.AnnAssign):
                info = self.field_processor.extract(item)
                fields.append(info)
            elif isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)):
                v_info = self.validator_processor.extract_info(item)
                if v_info:
                    validators.append(v_info)
                methods.append(item)
            elif PydanticDetector.is_config_class(item):
                config = self.config_processor.extract(item)
            elif isinstance(item, ast.Assign):
                # Check for model_config = ConfigDict(...)
                for target in item.targets:
                    if isinstance(target, ast.Name) and target.id == "model_config":
                        if PydanticDetector.is_config_dict(item.value):
                            if isinstance(item.value, ast.Call):
                                for kw in item.value.keywords:
                                    if kw.arg:
                                        configs[kw.arg] = self.visitor.visit(kw.value)

        # Check if we need to add imports
        for field in fields:
            if field.pattern:
                self.visitor.emitter.add_import("regex")
                break

        # Generate Struct
        export = "pub " if self.visitor._is_exported(struct_name) else ""

        struct_def = [
            f"// Pydantic Model: {struct_name}",
        ]

        if configs:
            config_comment = ", ".join([f"{k}={v}" for k, v in configs.items()])
            struct_def.append(f"// ConfigDict: {config_comment}")

        if config:
            opts = []
            if config.str_strip_whitespace: opts.append("str_strip_whitespace=true")
            if config.str_to_lower: opts.append("str_to_lower=true")
            if config.str_to_upper: opts.append("str_to_upper=true")
            if config.extra != 'ignore': opts.append(f"extra={config.extra}")
            if not config.allow_mutation: opts.append("allow_mutation=false")
            if config.validate_assignment: opts.append("validate_assignment=true")
            if opts:
                struct_def.append(f"// Config: {', '.join(opts)}")

        struct_def.append("@[params]")
        struct_def.append(f"{export}struct {struct_name} {{")

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
        validation_code = self._generate_validate_method(struct_name, fields, validators, export, config)
        if validation_code:
            self.visitor.emitter.add_function(validation_code)

        # We also need to visit methods, if any. We let the normal visitor handle methods,
        # but we pretend we are in this class.
        self.visitor.current_class = struct_name
        for method in methods:
            self.visitor.visit(method)
        self.visitor.current_class = None

        return "" # The emitter handles the actual output

    def _generate_validate_method(self, struct_name: str, fields: List[PydanticFieldInfo], validators: List[PydanticValidatorInfo], export: str, config: Optional[PydanticConfigInfo]) -> str:
        """Generates a .validate() method for the struct."""
        code = [
            f"{export}fn (mut m {struct_name}) validate() ! {{",
        ]

        has_validation = False

        # 1. Model validators (mode='before')
        for v in validators:
            if v.is_model_validator and v.mode == 'before':
                has_validation = True
                code.append(f"    m.{v.name}()")

        # 2. Field validators (mode='before')
        for v in validators:
            if not v.is_model_validator and v.mode == 'before':
                has_validation = True
                for f_name in v.fields:
                    code.append(f"    m.{f_name} = {struct_name}_{v.name}(m.{f_name})")

        # 3. Built-in field constraints
        for field_info in fields:
            vcode = self.field_processor.generate_validation_code(field_info, "m")
            if vcode:
                has_validation = True
                code.extend(vcode)

        # 4. Field validators (mode='after' or default)
        for v in validators:
            if not v.is_model_validator and (v.mode in ('after', 'default') or not v.mode):
                has_validation = True
                for f_name in v.fields:
                    # If it's a classmethod validator, it's called as Struct_name_validator(value)
                    # We assume it returns the validated value
                    code.append(f"    m.{f_name} = {struct_name}_{v.name}(m.{f_name})")

        # 5. Model validators (mode='after' or default)
        for v in validators:
            if v.is_model_validator and (v.mode in ('after', 'default') or not v.mode):
                has_validation = True
                code.append(f"    m.{v.name}()")

        if not has_validation and not (config and config.validate_all):
            return ""

        code.append("}")
        return "\n".join(code)
