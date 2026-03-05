import ast
from typing import Any, List

from .field_processor import PydanticFieldProcessor, PydanticFieldInfo
from .validator_processor import PydanticValidatorProcessor

class PydanticModelProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor
        self.field_processor = PydanticFieldProcessor(visitor)
        self.validator_processor = PydanticValidatorProcessor(visitor)

    def process_model(self, node: ast.ClassDef) -> str:
        """Generates a Vlang struct from a Pydantic BaseModel."""
        struct_name = self.visitor._sanitize_name(node.name)

        # Set current class context for validator processor
        prev_class = self.visitor.current_class
        self.visitor.current_class = struct_name

        # Handle generics
        py_generics = []
        if hasattr(node, "type_params") and node.type_params:
            for param in node.type_params:
                if hasattr(param, "name"):
                    name = param.name
                    if isinstance(name, str): py_generics.append(name)
                    elif hasattr(name, "id"): py_generics.append(name.id)

        # Also check Generic[T] in bases
        for base in node.bases:
            if isinstance(base, ast.Subscript) and isinstance(base.value, ast.Name) and base.value.id == "Generic":
                if isinstance(base.slice, ast.Tuple):
                    for elt in base.slice.elts:
                        if isinstance(elt, ast.Name): py_generics.append(elt.id)
                elif isinstance(base.slice, ast.Name):
                    py_generics.append(base.slice.id)

        if py_generics:
            if not hasattr(self.visitor, "current_class_generic_map"):
                self.visitor.current_class_generic_map = {}
            self.visitor.current_class_generic_map.update(self.visitor._get_generic_map(py_generics))
            self.visitor.generic_scopes.append(self.visitor.current_class_generic_map)
            self.visitor.current_class_generics = self.visitor._get_all_active_v_generics()

        fields: List[PydanticFieldInfo] = []
        configs = []

        # We need to collect fields and methods
        methods: List[ast.FunctionDef] = []
        for item in node.body:
            if isinstance(item, ast.AnnAssign):
                info = self.field_processor.extract(item)
                fields.append(info)
            elif isinstance(item, ast.Assign):
                # Check for model_config = ConfigDict(...)
                for target in item.targets:
                    if isinstance(target, ast.Name) and target.id == "model_config":
                        if isinstance(item.value, ast.Call):
                            for kw in item.value.keywords:
                                configs.append(f"// Pydantic Config: {kw.arg} = {self.visitor.visit(kw.value)}")
            elif isinstance(item, ast.ClassDef) and item.name == "Config":
                # Legacy Config class
                for stmt in item.body:
                    if isinstance(stmt, ast.Assign):
                        for target in stmt.targets:
                            if isinstance(target, ast.Name):
                                configs.append(f"// Pydantic Config: {target.id} = {self.visitor.visit(stmt.value)}")
            elif isinstance(item, ast.FunctionDef):
                # Will handle validators in validator_processor
                methods.append(item)
                self.validator_processor.process(item)

        # Generate Struct
        export = "pub " if self.visitor._is_exported(struct_name) else ""
        generics_str = f"[{', '.join(self.visitor.current_class_generics)}]" if self.visitor.current_class_generics else ""

        struct_def = [
            f"// Pydantic Model: {struct_name}",
        ]
        struct_def.extend(configs)
        struct_def.extend([
            "@[params]",
            f"{export}struct {struct_name}{generics_str} {{"
        ])

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
        for method in methods:
            self.visitor.visit(method)

        if py_generics:
            self.visitor.generic_scopes.pop()
            self.visitor.current_class_generics = [] # Simplified

        self.visitor.current_class = prev_class

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

        validator_calls = self.validator_processor.generate_validation_calls(struct_name)
        if validator_calls:
            has_validation = True
            code.extend(validator_calls)

        if not has_validation:
            return ""

        code.append("}")
        return "\n".join(code)
