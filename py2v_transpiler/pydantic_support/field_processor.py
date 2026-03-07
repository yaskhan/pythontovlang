import ast
from dataclasses import dataclass
from typing import Optional, List, Dict, Any

@dataclass
class PydanticFieldInfo:
    name: str
    type_str: str
    default_val: Optional[str] = None
    alias: Optional[str] = None
    gt: Optional[str] = None
    lt: Optional[str] = None
    ge: Optional[str] = None
    le: Optional[str] = None
    max_length: Optional[str] = None
    min_length: Optional[str] = None
    is_optional: bool = False
    pattern: Optional[str] = None
    multiple_of: Optional[str] = None
    min_items: Optional[str] = None
    max_items: Optional[str] = None
    unique_items: bool = False
    const: Optional[str] = None
    description: Optional[str] = None
    title: Optional[str] = None
    examples: Optional[str] = None
    repr: bool = True
    exclude: bool = False

class PydanticFieldProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor

    def extract(self, node: ast.AnnAssign) -> PydanticFieldInfo:
        """Extracts field info from an AnnAssign node, specifically looking for Field()."""
        name = node.target.id if isinstance(node.target, ast.Name) else "unknown"

        # Determine basic type
        from py2v_transpiler.models.v_types import _map_ast_type
        from .detector import PydanticDetector

        annotation = node.annotation
        field_node = None

        # Handle Annotated[T, Field(...)]
        if isinstance(annotation, ast.Subscript):
            if isinstance(annotation.value, ast.Name) and annotation.value.id == "Annotated":
                # Annotated[Type, Metadata1, Metadata2]
                if isinstance(annotation.slice, ast.Tuple):
                    # Python < 3.9 might have a different slice structure but ast.unparse/ast.parse mode='eval' handles it
                    # In 3.9+ it's ast.Tuple
                    elts = annotation.slice.elts
                    if elts:
                        annotation = elts[0] # The actual type
                        for metadata in elts[1:]:
                            if PydanticDetector.is_pydantic_field(metadata):
                                field_node = metadata
                                break

        ast_type_str = _map_ast_type(annotation)
        type_str = self.visitor._map_type(ast_type_str)
        is_optional = type_str.startswith("?")

        info = PydanticFieldInfo(name=name, type_str=type_str, is_optional=is_optional)

        # Priority 1: Field() in Annotated
        if field_node and isinstance(field_node, ast.Call):
            self._parse_field_kwargs(field_node, info)

        # Priority 2: Field() as the assigned value
        if node.value and isinstance(node.value, ast.Call):
            if PydanticDetector.is_pydantic_field(node.value):
                # It's a Field(...)
                self._parse_field_kwargs(node.value, info)
            else:
                # It's a standard default value like `x: int = 5`
                if not info.default_val:
                    info.default_val = self.visitor.visit(node.value)
        elif node.value:
            if not info.default_val:
                info.default_val = self.visitor.visit(node.value)

        return info

    def _parse_field_kwargs(self, node: ast.Call, info: PydanticFieldInfo):
        for keyword in node.keywords:
            if not keyword.arg:
                continue

            # Simple values we can visit right away
            val = self.visitor.visit(keyword.value)

            if keyword.arg == "alias":
                # Remove quotes for the struct tag later
                if val.startswith("'") or val.startswith('"'):
                    val = val[1:-1]
                info.alias = val
            elif keyword.arg == "default":
                if val != "none": # none in V is usually no default or optional
                    info.default_val = val
            elif keyword.arg == "default_factory":
                self.visitor.output.append(f"//##LLM@@ Pydantic 'Field(default_factory=...)' detected on field '{info.name}'. This is not fully supported by the transpiler. Please manually initialize the default value in the V struct or factory.")
            elif keyword.arg == "gt":
                info.gt = val
            elif keyword.arg == "lt":
                info.lt = val
            elif keyword.arg == "ge":
                info.ge = val
            elif keyword.arg == "le":
                info.le = val
            elif keyword.arg == "max_length":
                info.max_length = val
            elif keyword.arg == "min_length":
                info.min_length = val
            elif keyword.arg in ("pattern", "regex"):
                info.pattern = val
            elif keyword.arg == "multiple_of":
                info.multiple_of = val
            elif keyword.arg == "min_items":
                info.min_items = val
            elif keyword.arg == "max_items":
                info.max_items = val
            elif keyword.arg == "unique_items":
                info.unique_items = val == "true"
            elif keyword.arg == "const":
                info.const = val
            elif keyword.arg == "description":
                if val.startswith("'") or val.startswith('"'):
                    val = val[1:-1]
                info.description = val
            elif keyword.arg == "title":
                if val.startswith("'") or val.startswith('"'):
                    val = val[1:-1]
                info.title = val
            elif keyword.arg == "examples":
                info.examples = val
            elif keyword.arg == "repr":
                info.repr = val == "true"
            elif keyword.arg == "exclude":
                info.exclude = val == "true"

    def generate_struct_tags(self, info: PydanticFieldInfo) -> str:
        """Generates Vlang struct tags like [json: 'alias']."""
        tags = []
        if info.exclude:
            tags.append("json: '-'")
        elif info.alias:
            tags.append(f"json: '{info.alias}'")

        if info.description:
            tags.append(f"description: '{info.description}'")
        if info.title:
            tags.append(f"title: '{info.title}'")

        if tags:
             return f"[{'; '.join(tags)}]"
        return ""

    def generate_validation_code(self, info: PydanticFieldInfo, struct_var: str) -> List[str]:
        """Generates validation code for inside an init() factory or .validate() method."""
        code = []
        field_access = f"{struct_var}.{info.name}"

        # If it's an optional and has no value (represented as `none` in V),
        # we might skip validation or unwrap. For simplicity, we assume we check if it's not none if optional.
        indent = "    "
        prefix = ""

        if info.is_optional:
             code.append(f"{indent}if {field_access} != none {{")
             indent += "    "
             # In V, if you check `x != none`, you can use it as normal, but sometimes you need `x?` or similar.
             # We will just do a basic check assuming V's smart cast or explicit unwrapping isn't strictly needed for basic ops,
             # though strictly speaking V requires `val := x or { return }`.
             # To keep it simple, we do:
             prefix = field_access + "?"
        else:
             prefix = field_access

        if info.gt:
            code.append(f'{indent}if {prefix} <= {info.gt} {{ return error("Validation Error: {info.name} must be greater than {info.gt}") }}')
        if info.lt:
            code.append(f'{indent}if {prefix} >= {info.lt} {{ return error("Validation Error: {info.name} must be less than {info.lt}") }}')
        if info.ge:
            code.append(f'{indent}if {prefix} < {info.ge} {{ return error("Validation Error: {info.name} must be greater than or equal to {info.ge}") }}')
        if info.le:
            code.append(f'{indent}if {prefix} > {info.le} {{ return error("Validation Error: {info.name} must be less than or equal to {info.le}") }}')

        if info.max_length:
             code.append(f'{indent}if {prefix}.len > {info.max_length} {{ return error("Validation Error: {info.name} length must be <= {info.max_length}") }}')
        if info.min_length:
             code.append(f'{indent}if {prefix}.len < {info.min_length} {{ return error("Validation Error: {info.name} length must be >= {info.min_length}") }}')

        if info.pattern:
            code.append(f"{indent}if !regex.match({prefix}, {info.pattern}) {{ return error('Validation Error: {info.name} must match pattern') }}")

        if info.multiple_of:
            code.append(f"{indent}if {prefix} % {info.multiple_of} != 0 {{ return error('Validation Error: {info.name} must be multiple of {info.multiple_of}') }}")

        if info.min_items:
            code.append(f"{indent}if {prefix}.len < {info.min_items} {{ return error('Validation Error: {info.name} length must be >= {info.min_items}') }}")
        if info.max_items:
            code.append(f"{indent}if {prefix}.len > {info.max_items} {{ return error('Validation Error: {info.name} length must be <= {info.max_items}') }}")

        if info.unique_items:
            item_type = info.type_str
            if item_type.startswith("[]"):
                item_type = item_type[2:]
            elif item_type.startswith("map[") and "]bool" in item_type:
                # set[T] is map[T]bool
                item_type = item_type[4:item_type.find("]bool")]

            code.append(f"{indent}seen_{info.name} := map[{item_type}]bool{{}}")
            code.append(f"{indent}for item in {prefix} {{")
            code.append(f"{indent}    if item in seen_{info.name} {{ return error('Validation Error: {info.name} items must be unique') }}")
            code.append(f"{indent}    seen_{info.name}[item] = true")
            code.append(f"{indent}}}")

        if info.const:
            const_display = info.const
            if (const_display.startswith("'") and const_display.endswith("'")) or \
               (const_display.startswith('"') and const_display.endswith('"')):
                const_display = const_display[1:-1]
            code.append(f"{indent}if {prefix} != {info.const} {{ return error('Validation Error: {info.name} must be {const_display}') }}")

        if info.is_optional:
            code.append("    }")

        return code
