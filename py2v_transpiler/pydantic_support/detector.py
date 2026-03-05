import ast
from typing import TypeGuard

class PydanticDetector:
    @staticmethod
    def is_pydantic_model(node: ast.ClassDef) -> bool:
        """Checks if a class definition inherits from BaseModel."""
        for base in node.bases:
            if isinstance(base, ast.Name) and base.id == "BaseModel":
                return True
            if isinstance(base, ast.Attribute) and base.attr == "BaseModel" and getattr(base.value, "id", "") == "pydantic":
                return True
        return False

    @staticmethod
    def is_pydantic_field(node: ast.expr) -> bool:
        """Checks if an expression is a call to pydantic.Field()."""
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name) and node.func.id == "Field":
                return True
            if isinstance(node.func, ast.Attribute) and node.func.attr == "Field" and getattr(node.func.value, "id", "") == "pydantic":
                return True
        return False

    @staticmethod
    def is_validator_decorator(node: ast.expr) -> bool:
        """Checks if a decorator is a Pydantic validator (e.g. @field_validator)."""
        if isinstance(node, ast.Name):
            return node.id in ("validator", "field_validator", "model_validator")
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            return node.func.id in ("validator", "field_validator", "model_validator")
        if isinstance(node, ast.Attribute) and node.attr in ("validator", "field_validator", "model_validator"):
             return True
        return False

    @staticmethod
    def is_config_class(node: ast.AST) -> TypeGuard[ast.ClassDef]:
        """Checks if a class definition is a nested Config class."""
        return isinstance(node, ast.ClassDef) and node.name == "Config"
