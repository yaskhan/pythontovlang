import ast
from typing import Any, List, Optional
from dataclasses import dataclass

@dataclass
class PydanticValidatorInfo:
    name: str
    fields: List[str]
    node: Optional[ast.FunctionDef | ast.AsyncFunctionDef] = None
    mode: str = "after" # 'before', 'after', 'wrap', 'plain'
    is_model_validator: bool = False

class PydanticValidatorProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor

    def extract_info(self, node: ast.FunctionDef | ast.AsyncFunctionDef) -> Optional[PydanticValidatorInfo]:
        """Extracts validator info from a function definition."""
        is_field_validator = False
        is_model_validator = False
        fields = []
        mode = "after"

        for decorator in node.decorator_list:
            dec_name = ""
            dec_args = []
            dec_keywords = {}

            if isinstance(decorator, ast.Name):
                dec_name = decorator.id
            elif isinstance(decorator, ast.Attribute):
                dec_name = decorator.attr
            elif isinstance(decorator, ast.Call):
                if isinstance(decorator.func, ast.Name):
                    dec_name = decorator.func.id
                elif isinstance(decorator.func, ast.Attribute):
                    dec_name = decorator.func.attr

                for arg in decorator.args:
                    if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                        dec_args.append(arg.value)
                for kw in decorator.keywords:
                    if kw.arg:
                        dec_keywords[kw.arg] = kw.value

            if dec_name in ("validator", "field_validator"):
                is_field_validator = True
                fields.extend(dec_args)
                if "mode" in dec_keywords:
                    val = dec_keywords["mode"]
                    if isinstance(val, ast.Constant) and isinstance(val.value, str):
                        mode = val.value
                elif "pre" in dec_keywords:
                    val = dec_keywords["pre"]
                    if isinstance(val, ast.Constant) and val.value is True:
                        mode = "before"

            elif dec_name in ("model_validator", "root_validator"):
                is_model_validator = True
                if "mode" in dec_keywords:
                    val = dec_keywords["mode"]
                    if isinstance(val, ast.Constant) and isinstance(val.value, str):
                        mode = val.value
                elif "pre" in dec_keywords:
                    val = dec_keywords["pre"]
                    if isinstance(val, ast.Constant) and val.value is True:
                        mode = "before"

        if is_field_validator:
            return PydanticValidatorInfo(name=node.name, fields=fields, node=node, mode=mode, is_model_validator=False)
        if is_model_validator:
            return PydanticValidatorInfo(name=node.name, fields=[], node=node, mode=mode, is_model_validator=True)

        return None

    def process(self, node: ast.FunctionDef | ast.AsyncFunctionDef) -> str:
        """Processes Pydantic validator methods, converting them to standard methods with special names or registering them."""
        # The actual function body is visited by the normal visitor.
        # This method is currently called from ClassesMixin if it's a Pydantic model.
        # But ModelProcessor now calls visitor.visit(method) directly.
        return self.visitor.visit(node)
