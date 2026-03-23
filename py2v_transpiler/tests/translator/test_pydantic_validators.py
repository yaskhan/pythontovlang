import unittest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.tests.translator.utils import translate_with_mypy

class TestPydanticValidators(unittest.TestCase):
    def setUp(self):
        self.parser = PyASTParser()
        self.type_inference = TypeInference()

    def translate(self, code: str) -> str:
        return translate_with_mypy(code, self.parser, self.type_inference)

    def test_field_validator(self):
        code = """
from pydantic import BaseModel, field_validator

class User(BaseModel):
    name: str

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        if len(v) < 2:
            raise ValueError('Name too short')
        return v.title()
"""
        v_code = self.translate(code)
        # Check if validate() calls the anonymous function correctly
        self.assertIn("m.name = fn (v string) !string {", v_code)
        self.assertIn("return error('Name too short')", v_code)
        self.assertIn("}(m.name) !", v_code)
        # Ensure it is not also visited as a normal method
        self.assertNotIn("fn User_validate_name", v_code)

    def test_model_validator(self):
        code = """
from pydantic import BaseModel, model_validator

class User(BaseModel):
    password: str
    confirm_password: str

    @model_validator(mode='after')
    def check_passwords(self) -> 'User':
        if self.password != self.confirm_password:
            raise ValueError('Passwords do not match')
        return self
"""
        v_code = self.translate(code)
        self.assertIn("m = fn (mut self User) !User {", v_code)
        self.assertIn("return error('Passwords do not match')", v_code)
        self.assertIn("}(mut m) !", v_code)

    def test_legacy_validator(self):
        code = """
from pydantic import BaseModel, validator

class User(BaseModel):
    name: str

    @validator('name', pre=True)
    def validate_name(cls, v: str) -> str:
        if not v:
            raise ValueError('Empty name')
        return v
"""
        v_code = self.translate(code)
        # validator(pre=True) -> mode='before'
        # In validate_method, before-validators come before field constraints.
        # We can't easily check order without more regex, but we check presence.
        self.assertIn("m.name = fn (v string) !string {", v_code)
        self.assertIn("return error('Empty name')", v_code)

    def test_root_validator(self):
        code = """
from pydantic import BaseModel, root_validator

class User(BaseModel):
    a: int
    b: int

    @root_validator(pre=False)
    def check_sum(cls, values: dict) -> dict:
        if values.get('a', 0) + values.get('b', 0) > 10:
            raise ValueError('Sum too large')
        return values
"""
        v_code = self.translate(code)
        # root_validator maps to model_validator in our processor
        self.assertIn("m = fn (mut self User) !User {", v_code)
        # Note: 'values' in root_validator(pre=False) is a dict, but our closure uses 'self' (the struct)
        # This is an approximation as V doesn't use dicts for Pydantic models.
        # However, the user-defined logic might need manual adjustment if they use .get() on a struct.
        # But for now, we follow the closure pattern.
        self.assertIn("return error('Sum too large')", v_code)

if __name__ == "__main__":
    unittest.main()
