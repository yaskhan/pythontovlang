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
        struct_name = self.visitor._sanitize_name(node.name, is_type=True)

        # Check for BaseModel[T]
        for base in node.bases:
            if isinstance(base, ast.Subscript) and (getattr(base.value, "id", "") == "BaseModel" or getattr(base.value, "attr", "") == "BaseModel"):
                self.visitor.output.append(f"//##LLM@@ Pydantic Generic model (BaseModel[T]) detected in '{struct_name}'. This requires manual type annotation and adjustments in V. Please review the generated struct.")
                break
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
                else:
                    methods.append(item)
            elif PydanticDetector.is_config_class(item):
                config = self.config_processor.extract(item)
            elif isinstance(item, ast.Assign):
                # Check for model_config = ConfigDict(...)
                for target in item.targets:
                    if isinstance(target, ast.Name) and target.id == "model_config":
                        if PydanticDetector.is_config_dict(item.value):
                            if isinstance(item.value, ast.Call):
                                config = self.config_processor.extract_from_config_dict(item.value)
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

        if configs and not config: # Only show ConfigDict if not already processed into config object
            config_comment = ", ".join(f"{k}={v}" for k, v in configs.items())
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
        self.visitor.defined_classes[struct_name] = {
            "has_init": False,
            "has_new": False,
            "is_pydantic": True
        }
        self.visitor.emitter.add_struct("\n".join(struct_def))

        # Generate automatic factory if no __init__ is present
        has_init = any(isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef)) and m.name == "__init__" for m in methods)
        if not has_init:
            factory_code = self._generate_factory_method(struct_name, fields, export)
            self.visitor.emitter.add_function(factory_code)
            self.visitor.defined_classes[struct_name]["has_init"] = True
            self.visitor.defined_classes[struct_name]["has_new"] = True

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

        # Apply Config transformations
        if config:
            for field_info in fields:
                if field_info.type_str == "string":
                    if config.str_strip_whitespace:
                        code.append(f"    m.{field_info.name} = m.{field_info.name}.trim()")
                        has_validation = True
                    if config.str_to_lower:
                        code.append(f"    m.{field_info.name} = m.{field_info.name}.to_lower()")
                        has_validation = True
                    if config.str_to_upper:
                        code.append(f"    m.{field_info.name} = m.{field_info.name}.to_upper()")
                        has_validation = True

                    if config.min_anystr_length is not None:
                        code.append(f'    if m.{field_info.name}.len < {config.min_anystr_length} {{ return error("Validation Error: {field_info.name} length must be >= {config.min_anystr_length}") }}')
                        has_validation = True
                    if config.max_anystr_length is not None:
                        code.append(f'    if m.{field_info.name}.len > {config.max_anystr_length} {{ return error("Validation Error: {field_info.name} length must be <= {config.max_anystr_length}") }}')
                        has_validation = True

        # 1. Model validators (mode='before')
        for v in validators:
            if v.is_model_validator and v.mode == 'before':
                v_logic = self._generate_validator_logic(v, struct_name, fields)
                if v_logic:
                    has_validation = True
                    code.extend(v_logic)

        # 2. Field validators (mode='before')
        for v in validators:
            if not v.is_model_validator and v.mode == 'before':
                v_logic = self._generate_validator_logic(v, struct_name, fields)
                if v_logic:
                    has_validation = True
                    code.extend(v_logic)

        # 3. Built-in field constraints
        for field_info in fields:
            # Check for Nested models
            # If the type is in defined_classes and is a pydantic model, flag it
            # Since we can't be 100% sure just by type_str if it's imported, we do a basic check
            # if type_str starts with uppercase and isn't a basic type
            is_potential_nested = False
            if field_info.type_str and field_info.type_str[0].isupper() and field_info.type_str not in ("Any", "String", "Int", "Bool", "Float"):
                info_class = self.visitor.defined_classes.get(field_info.type_str, {})
                if info_class.get("is_pydantic", False) or not info_class: # If not in defined_classes it might be imported
                     # To avoid spamming on every uppercase type, let's strictly check if it's known as pydantic
                     if info_class.get("is_pydantic", False):
                         is_potential_nested = True

            if is_potential_nested:
                code.append(f"    //##LLM@@ Pydantic Nested model field '{field_info.name}' detected. The generated validation is flattened and does not automatically call `.validate()` on nested models. Please implement recursive validation manually.")
                has_validation = True

            vcode = self.field_processor.generate_validation_code(field_info, "m")
            if vcode:
                has_validation = True
                code.extend(vcode)

        # 4. Field validators (mode='after' or default)
        for v in validators:
            if not v.is_model_validator and (v.mode in ('after', 'default') or not v.mode):
                v_logic = self._generate_validator_logic(v, struct_name, fields)
                if v_logic:
                    has_validation = True
                    code.extend(v_logic)

        # 5. Model validators (mode='after' or default)
        for v in validators:
            if v.is_model_validator and (v.mode in ('after', 'default') or not v.mode):
                v_logic = self._generate_validator_logic(v, struct_name, fields)
                if v_logic:
                    has_validation = True
                    code.extend(v_logic)

        if not has_validation and not (config and config.validate_all):
            return ""

        code.append("}")
        return "\n".join(code)

    def _generate_validator_logic(self, v_info: PydanticValidatorInfo, struct_name: str, fields: List[PydanticFieldInfo]) -> List[str]:
        node = v_info.node
        if not node:
            return []

        res = []
        field_map = {f.name: f for f in fields}

        # Save visitor state
        old_output = self.visitor.output
        old_indent = self.visitor._indent_level
        old_in_validator = self.visitor.in_pydantic_validator
        old_remap = self.visitor.name_remap.copy()
        old_ret_type = getattr(self.visitor, 'current_function_return_type', None)

        self.visitor.in_pydantic_validator = True
        self.visitor._indent_level = 2

        try:
            if v_info.is_model_validator:
                res.append(f"    m = fn (mut self {struct_name}) !{struct_name} {{")
                self.visitor.output = []
                self.visitor.current_function_return_type = struct_name

                real_args = node.args.args
                if real_args:
                    self.visitor.name_remap[real_args[0].arg] = "self"

                body = node.body
                if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
                    body = body[1:]

                for stmt in body:
                    self.visitor.visit(stmt)

                for line in self.visitor.output:
                    res.append(line)
                res.append("    }(mut m) !")
            else:
                for f_name in v_info.fields:
                    f_info = field_map.get(f_name)
                    f_type = f_info.type_str if f_info else "Any"

                    res.append(f"    m.{f_name} = fn (v {f_type}) !{f_type} {{")
                    self.visitor.output = []
                    self.visitor.current_function_return_type = f_type

                    real_args = node.args.args
                    if real_args and real_args[0].arg in ('cls', 'self'):
                        real_args = real_args[1:]

                    if real_args:
                        self.visitor.name_remap[real_args[0].arg] = "v"

                    body = node.body
                    if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
                        body = body[1:]

                    for stmt in body:
                        self.visitor.visit(stmt)

                    for line in self.visitor.output:
                        res.append(line)
                    res.append(f"    }}(m.{f_name}) !")
        finally:
            self.visitor.output = old_output
            self.visitor._indent_level = old_indent
            self.visitor.in_pydantic_validator = old_in_validator
            self.visitor.name_remap = old_remap
            self.visitor.current_function_return_type = old_ret_type

        return res

    def _generate_factory_method(self, struct_name: str, fields: List[PydanticFieldInfo], export: str) -> str:
        """Generates a new_StructName factory function."""
        factory_name = self.visitor._get_factory_name(struct_name)
        required = [f for f in fields if not f.default_val]
        optional = [f for f in fields if f.default_val]

        args = []
        for f in required:
            args.append(f"{f.name} {f.type_str}")

        # V doesn't support optional parameters. We make the last optional field variadic.
        # The ones before it remain required in the factory signature.
        for f in optional[:-1]:
            args.append(f"{f.name} {f.type_str}")

        if optional:
            last = optional[-1]
            args.append(f"{last.name} ...{last.type_str}")

        args_str = ", ".join(args)
        code = [
            f"// {factory_name} creates a new {struct_name} and validates it.",
            f"{export}fn {factory_name}({args_str}) !{struct_name} {{",
            f"    mut self := {struct_name}{{"
        ]

        for f in required:
            code.append(f"        {f.name}: {f.name}")
        for f in optional[:-1]:
            code.append(f"        {f.name}: {f.name}")

        if optional:
            last = optional[-1]
            dv = last.default_val if last.default_val else "none"
            # Handle variadic parameter: if empty use default
            code.append(f"        {last.name}: if {last.name}.len > 0 {{ {last.name}[0] }} else {{ {dv} }}")

        code.append("    }")
        code.append("    self.validate() or { return err }")
        code.append("    return self")
        code.append("}")
        return "\n".join(code)
