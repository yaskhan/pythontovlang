import unittest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.tests.translator.utils import translate_with_mypy

class TestPydanticV2Support(unittest.TestCase):
    def setUp(self):
        self.parser = PyASTParser()
        self.type_inference = TypeInference()

    def translate(self, code: str) -> str:
        return translate_with_mypy(code, self.parser, self.type_inference)

    def test_pydantic_v2_features(self):
        code = """
from pydantic import BaseModel, Field, field_validator, model_validator, computed_field, ConfigDict
from typing import Annotated

class User(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    name: Annotated[str, Field(min_length=2, max_length=50)]
    email: str

    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if '@' not in v:
            raise ValueError('Invalid email')
        return v.lower()

    @computed_field
    @property
    def display_name(self) -> str:
        return f"{self.name} <{self.email}>"
"""
        v_code = self.translate(code)

        # Check ConfigDict
        self.assertIn("// Config: str_strip_whitespace=true", v_code)

        # Check Annotated + Field
        self.assertIn("name string", v_code)
        self.assertIn('if m.name.len > 50 { return error("Validation Error: name length must be <= 50")', v_code)
        self.assertIn('if m.name.len < 2 { return error("Validation Error: name length must be >= 2")', v_code)

        # Check field_validator integration
        self.assertIn("m.email = fn (v string) !string {", v_code)
        self.assertIn("if '@' !in v {", v_code)
        self.assertIn("return error('Invalid email')", v_code)

        # Check computed_field (as a method)
        self.assertIn("fn (self User) display_name() string {", v_code)
        self.assertIn("return '${self.name} <${self.email}>'", v_code)

    def test_model_validator(self):
        code = """
from pydantic import BaseModel, model_validator

class MyModel(BaseModel):
    x: int
    y: int

    @model_validator(mode='after')
    def check_sum(self) -> "MyModel":
        if self.x + self.y > 100:
            raise ValueError('sum too large')
        return self
"""
        v_code = self.translate(code)
        self.assertIn("fn (mut m MyModel) validate() ! {", v_code)
        self.assertIn("m = fn (mut self MyModel) !MyModel {", v_code)
        self.assertIn("if self.x + self.y > 100 {", v_code)
        self.assertIn("return error('sum too large')", v_code)
        self.assertIn("}(mut m) !", v_code)
