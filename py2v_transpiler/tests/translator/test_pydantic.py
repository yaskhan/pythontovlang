import ast
import unittest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestPydanticSupport(unittest.TestCase):
    def setUp(self):
        self.parser = PyASTParser()
        self.type_inference = TypeInference()

    def translate(self, code: str) -> str:
        tree = self.parser.parse(code)
        self.type_inference.run_mypy(code)
        visitor = VNodeVisitor(self.type_inference)
        visitor.visit(tree)
        return visitor.emitter.emit()

    def test_basic_pydantic_model(self):
        code = """
from pydantic import BaseModel, Field

class User(BaseModel):
    id: int
    name: str = Field(alias='userName', max_length=50)
    age: int = Field(gt=0, default=18)
    is_active: bool = True
"""
        v_code = self.translate(code)

        # Check struct and tags
        self.assertIn("struct User {", v_code)
        self.assertIn("id int", v_code)
        self.assertIn("name string [json: 'userName']", v_code)
        self.assertIn("age int = 18", v_code)
        self.assertIn("is_active bool = true", v_code)

        # Check validation method
        self.assertIn("fn (mut m User) validate() ! {", v_code)
        self.assertIn("if m.name.len > 50 { return error('Validation Error: name length must be <= 50')", v_code)
        self.assertIn("if m.age <= 0 { return error('Validation Error: age must be greater than 0')", v_code)

    def test_optional_field(self):
        code = """
from typing import Optional
from pydantic import BaseModel, Field

class Item(BaseModel):
    price: Optional[float] = Field(gt=0.0)
"""
        v_code = self.translate(code)
        self.assertIn("price ?f64", v_code)
        self.assertIn("if m.price != none {", v_code)
        self.assertIn("if m.price? <= 0.0 {", v_code)
