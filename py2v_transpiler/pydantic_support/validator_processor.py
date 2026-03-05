import ast
from typing import Any, List, Dict, Optional
from dataclasses import dataclass

@dataclass
class PydanticValidatorInfo:
    name: str
    fields: List[str]
    mode: str = "after" # 'before', 'after', 'wrap', 'plain'
    is_model_validator: bool = False

class PydanticValidatorProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor
        self.validators: Dict[str, List[Dict[str, Any]]] = {} # class_name -> list of validator info

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
            elif dec_name in ("model_validator", "root_validator"):
                is_model_validator = True
                if "mode" in dec_keywords:
                    val = dec_keywords["mode"]
                    if isinstance(val, ast.Constant) and isinstance(val.value, str):
                        mode = val.value

        if is_field_validator:
            return PydanticValidatorInfo(name=node.name, fields=fields, mode=mode, is_model_validator=False)
        if is_model_validator:
            return PydanticValidatorInfo(name=node.name, fields=[], mode=mode, is_model_validator=True)

        return None

    def process(self, node: ast.FunctionDef | ast.AsyncFunctionDef) -> str:
        """Processes Pydantic validator methods, converting them to standard methods with special names or registering them."""
        return self.visitor.visit(node)

    def generate_validation_calls(self, class_name: str) -> List[str]:
        # This method is now redundant because ModelProcessor uses PydanticValidatorInfo
        # but I'll keep it for compatibility if needed.
        return []
