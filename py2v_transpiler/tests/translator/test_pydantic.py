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
        code = r"""
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
        self.assertIn('if m.name.len > 50 { return error("Validation Error: name length must be <= 50")', v_code)
        self.assertIn('if m.age <= 0 { return error("Validation Error: age must be greater than 0")', v_code)

    def test_optional_field(self):
        code = r"""
from typing import Optional
from pydantic import BaseModel, Field

class Item(BaseModel):
    price: Optional[float] = Field(gt=0.0)
"""
        v_code = self.translate(code)
        self.assertIn("price ?f64", v_code)
        self.assertIn("if m.price != none {", v_code)
        self.assertIn("if m.price? <= 0.0 {", v_code)

    def test_extended_field_constraints(self):
        code = r"""
from pydantic import BaseModel, Field
from typing import List

class Product(BaseModel):
    sku: str = Field(pattern=r'^[A-Z]{3}-\d{4}$', title='Stock Keeping Unit', description='A unique SKU')
    price: float = Field(multiple_of=0.01)
    tags: List[str] = Field(min_items=1, max_items=10, unique_items=True)
    category: str = Field(const='electronics', exclude=True)
"""
        v_code = self.translate(code)

        # Check struct and tags
        self.assertIn("sku string [description: 'A unique SKU'; title: 'Stock Keeping Unit']", v_code)
        self.assertIn("price f64", v_code)
        self.assertIn("tags []string", v_code)
        self.assertIn("category string [json: '-']", v_code)

        # Check imports
        self.assertIn("import regex", v_code)

        # Check validation logic
        self.assertIn("if !regex.match(m.sku, r'^[A-Z]{3}-\\d{4}$') { return error('Validation Error: sku must match pattern') }", v_code)
        self.assertIn("if m.price % 0.01 != 0 { return error('Validation Error: price must be multiple of 0.01') }", v_code)
        self.assertIn("if m.tags.len < 1 { return error('Validation Error: tags length must be >= 1') }", v_code)
        self.assertIn("if m.tags.len > 10 { return error('Validation Error: tags length must be <= 10') }", v_code)

        # Check uniqueness loop
        self.assertIn("seen_tags := map[string]bool{}", v_code)
        self.assertIn("for item in m.tags {", v_code)
        self.assertIn("if item in seen_tags { return error('Validation Error: tags items must be unique') }", v_code)
        self.assertIn("seen_tags[item] = true", v_code)

        # Check const
        self.assertIn("if m.category != 'electronics' { return error('Validation Error: category must be electronics') }", v_code)

    def test_pydantic_config_str_transformations(self):
        code = r"""
from pydantic import BaseModel

class User(BaseModel):
    name: str
    email: str

    class Config:
        str_strip_whitespace = True
        str_to_lower = True
"""
        v_code = self.translate(code)
        self.assertIn("// Config: str_strip_whitespace=true, str_to_lower=true", v_code)
        self.assertIn("m.name = m.name.trim()", v_code)
        self.assertIn("m.name = m.name.to_lower()", v_code)
        self.assertIn("m.email = m.email.trim()", v_code)
        self.assertIn("m.email = m.email.to_lower()", v_code)

    def test_pydantic_config_mutation_and_extra(self):
        code = r"""
from pydantic import BaseModel

class User(BaseModel):
    name: str

    class Config:
        allow_mutation = False
        extra = 'forbid'
"""
        v_code = self.translate(code)
        self.assertIn("// Config: extra=forbid, allow_mutation=false", v_code)
        # Should not have 'mut' in struct definition for private/local
        self.assertIn("struct User {", v_code)
        self.assertNotIn("mut:", v_code)
        self.assertIn("name string", v_code)

    def test_pydantic_config_anystr_length(self):
        code = r"""
from pydantic import BaseModel

class User(BaseModel):
    name: str

    class Config:
        min_anystr_length = 3
        max_anystr_length = 20
"""
        v_code = self.translate(code)
        self.assertIn('if m.name.len < 3 { return error("Validation Error: name length must be >= 3") }', v_code)
        self.assertIn('if m.name.len > 20 { return error("Validation Error: name length must be <= 20") }', v_code)
