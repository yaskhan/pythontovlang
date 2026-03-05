import ast
from typing import Any

class PydanticValidatorProcessor:
    def __init__(self, visitor: Any):
        self.visitor = visitor
        self.validators = {} # class_name -> list of validator info

    def process(self, node: ast.FunctionDef) -> str:
        """Processes Pydantic validator methods, converting them to standard methods with special names or registering them."""
        class_name = self.visitor.current_class
        if not class_name:
            return self.visitor.visit(node)

        is_field_val = False
        is_model_val = False
        fields = []

        from .detector import PydanticDetector
        for dec in node.decorator_list:
            if PydanticDetector.is_validator_decorator(dec):
                dec_name = ""
                if isinstance(dec, ast.Name): dec_name = dec.id
                elif isinstance(dec, ast.Call) and isinstance(dec.func, ast.Name): dec_name = dec.func.id
                elif isinstance(dec, ast.Attribute): dec_name = dec.attr

                if dec_name in ("validator", "field_validator"):
                    is_field_val = True
                    # Extract field names
                    if isinstance(dec, ast.Call):
                        for arg in dec.args:
                            if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                                fields.append(arg.value)
                elif dec_name == "model_validator":
                    is_model_val = True

        if is_field_val or is_model_val:
            if class_name not in self.validators:
                self.validators[class_name] = []

            self.validators[class_name].append({
                "name": node.name,
                "is_field": is_field_val,
                "is_model": is_model_val,
                "fields": fields
            })

        # Generate the function itself
        # We need to ensure it returns ! (result or error) in V if it raises ValueError
        # For simplicity, we just visit it.
        return self.visitor.visit(node)

    def generate_validation_calls(self, class_name: str) -> list[str]:
        calls = []
        if class_name not in self.validators:
            return calls

        for v in self.validators[class_name]:
            if v["is_field"]:
                for field in v["fields"]:
                    # m.field = Class_method(m.field) !
                    calls.append(f"    m.{field} = {class_name}_{v['name']}(m.{field}) !")
            elif v["is_model"]:
                # m.method() !
                calls.append(f"    m.{v['name']}() !")

        return calls
