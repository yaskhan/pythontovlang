import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

@pytest.fixture
def transpiler():
    parser = PyASTParser()
    type_inference = TypeInference()

    def _translate(code: str) -> str:
        tree = parser.parse(code)
        type_inference.run_mypy(code)
        visitor = VNodeVisitor(type_inference)
        visitor.visit(tree)
        return visitor.emitter.emit()

    return _translate

def test_basic_pydantic_model(transpiler):
    code = """
from pydantic import BaseModel, Field

class User(BaseModel):
    id: int
    name: str = Field(alias='userName', max_length=50)
    age: int = Field(gt=0, default=18)
    is_active: bool = True
"""
    v_code = transpiler(code)

    # Check struct and tags
    assert "struct User {" in v_code
    assert "id int" in v_code
    assert "name string [json: 'userName']" in v_code
    assert "age int = 18" in v_code
    assert "is_active bool = true" in v_code

    # Check validation method
    assert "fn (mut m User) validate() ! {" in v_code
    assert "if m.name.len > 50 { return error('Validation Error: name length must be <= 50')" in v_code
    assert "if m.age <= 0 { return error('Validation Error: age must be greater than 0')" in v_code

def test_optional_field(transpiler):
    code = """
from typing import Optional
from pydantic import BaseModel, Field

class Item(BaseModel):
    price: Optional[float] = Field(gt=0.0)
"""
    v_code = transpiler(code)
    assert "price ?f64" in v_code
    assert "if m.price != none {" in v_code
    assert "if m.price? <= 0.0 {" in v_code

def test_nested_models(transpiler):
    code = """
from pydantic import BaseModel

class Address(BaseModel):
    street: str
    city: str

class User(BaseModel):
    name: str
    address: Address
"""
    v_code = transpiler(code)
    assert "struct Address {" in v_code
    assert "struct User {" in v_code
    assert "address Address" in v_code

def test_private_attributes(transpiler):
    code = """
from pydantic import BaseModel, PrivateAttr

class MyModel(BaseModel):
    public_field: str
    _private_field: str = PrivateAttr(default="secret")
"""
    v_code = transpiler(code)
    assert "public_field string" in v_code
    # V doesn't support leading underscores for field names usually,
    # but the transpiler currently preserves them (as per AGENTS.md known issues).
    # PrivateAttr should ideally be handled by NOT putting it in [params] or making it non-pub.
    assert "_private_field string = 'secret'" in v_code

def test_model_with_methods(transpiler):
    code = """
from pydantic import BaseModel

class User(BaseModel):
    first_name: str
    last_name: str

    def get_full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"
"""
    v_code = transpiler(code)
    assert "struct User {" in v_code
    assert "fn (self User) get_full_name() string {" in v_code
    assert "return '${self.first_name} ${self.last_name}'" in v_code

def test_pydantic_generic_model(transpiler):
    code = """
from typing import Generic, TypeVar
from pydantic import BaseModel

T = TypeVar('T')

class Response(BaseModel, Generic[T]):
    data: T
    error: str | None
"""
    v_code = transpiler(code)
    assert "struct Response[T] {" in v_code
    assert "data T" in v_code

def test_pydantic_computed_field(transpiler):
    code = """
from pydantic import BaseModel, computed_field

class User(BaseModel):
    first_name: str
    last_name: str

    @computed_field
    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"
"""
    v_code = transpiler(code)
    # V property is just a method
    assert "fn (self User) full_name() string {" in v_code

def test_pydantic_validation_error_handling(transpiler):
    code = """
from pydantic import BaseModel, Field, ValidationError

class User(BaseModel):
    age: int = Field(gt=0)

try:
    User(age=-1).validate()
except ValidationError as e:
    print(e)
"""
    v_code = transpiler(code)
    assert "if C.try() {" in v_code
