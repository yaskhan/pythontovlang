import ast
from dataclasses import dataclass, field
from typing import Any, Dict, Optional

@dataclass
class PydanticConfigInfo:
    str_strip_whitespace: bool = False
    str_to_lower: bool = False
    str_to_upper: bool = False
    min_anystr_length: Optional[int] = None
    max_anystr_length: Optional[int] = None
    validate_all: bool = False
    validate_assignment: bool = False
    extra: str = 'ignore' # 'allow', 'ignore', 'forbid'
    allow_mutation: bool = True

class PydanticConfigProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor

    def extract(self, node: ast.ClassDef) -> PydanticConfigInfo:
        """Extracts configuration options from a Pydantic Config class."""
        info = PydanticConfigInfo()

        for item in node.body:
            if isinstance(item, ast.Assign):
                for target in item.targets:
                    if isinstance(target, ast.Name):
                        self._process_option(target.id, item.value, info)
            elif isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Name):
                if item.value:
                    self._process_option(item.target.id, item.value, info)

        return info

    def _process_option(self, name: str, value_node: ast.AST, info: PydanticConfigInfo):
        try:
            # We use ast.literal_eval for simple values if possible
            val = ast.literal_eval(value_node)
        except (ValueError, SyntaxError):
            # Fallback to visitor for more complex expressions if needed,
            # though Config options are usually literals.
            val = self.visitor.visit(value_node)
            if val == 'true': val = True
            elif val == 'false': val = False
            elif val.startswith("'") or val.startswith('"'):
                val = val[1:-1]

        if name == "str_strip_whitespace":
            info.str_strip_whitespace = bool(val)
        elif name == "str_to_lower":
            info.str_to_lower = bool(val)
        elif name == "str_to_upper":
            info.str_to_upper = bool(val)
        elif name == "min_anystr_length":
            info.min_anystr_length = int(val) if val is not None else None
        elif name == "max_anystr_length":
            info.max_anystr_length = int(val) if val is not None else None
        elif name == "validate_all":
            info.validate_all = bool(val)
        elif name == "validate_assignment":
            info.validate_assignment = bool(val)
        elif name == "extra":
            info.extra = str(val)
        elif name == "allow_mutation":
            info.allow_mutation = bool(val)
