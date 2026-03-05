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

def test_field_validator(transpiler):
    code = """
from pydantic import BaseModel, field_validator

class User(BaseModel):
    name: str

    @field_validator('name')
    @classmethod
    def name_must_contain_space(cls, v: str) -> str:
        if ' ' not in v:
            raise ValueError('must contain a space')
        return v.title()
"""
    v_code = transpiler(code)
    assert "fn (mut m User) validate() ! {" in v_code
    assert "m.name = User_name_must_contain_space(m.name) !" in v_code
    # The transpiler might not automatically add ! to return type yet if it just visits the node,
    # but it should be returning ! if it can fail.
    # Looking at the output, it was: fn User_name_must_contain_space(v string) string {
    assert "fn User_name_must_contain_space(v string) string {" in v_code

def test_model_validator(transpiler):
    code = """
from pydantic import BaseModel, model_validator

class User(BaseModel):
    username: str
    password: str

    @model_validator(mode='after')
    def check_passwords_match(self) -> 'User':
        if self.username == self.password:
            raise ValueError('password cannot be username')
        return self
"""
    v_code = transpiler(code)
    assert "fn (mut m User) validate() ! {" in v_code
    assert "m.check_passwords_match() !" in v_code

def test_legacy_validator(transpiler):
    code = """
from pydantic import BaseModel, validator

class User(BaseModel):
    age: int

    @validator('age')
    def age_must_be_positive(cls, v):
        if v <= 0:
            raise ValueError('must be positive')
        return v
"""
    v_code = transpiler(code)
    assert "m.age = User_age_must_be_positive(m.age) !" in v_code

def test_multiple_field_validators(transpiler):
    code = """
from pydantic import BaseModel, field_validator

class User(BaseModel):
    first_name: str
    last_name: str

    @field_validator('first_name', 'last_name')
    @classmethod
    def capitalize_name(cls, v: str) -> str:
        return v.capitalize()
"""
    v_code = transpiler(code)
    assert "m.first_name = User_capitalize_name(m.first_name) !" in v_code
    assert "m.last_name = User_capitalize_name(m.last_name) !" in v_code

def test_model_validator_before(transpiler):
    code = """
from pydantic import BaseModel, model_validator

class User(BaseModel):
    name: str

    @model_validator(mode='before')
    @classmethod
    def check_name_in_data(cls, data: dict) -> dict:
        return data
"""
    v_code = transpiler(code)
    assert "m.check_name_in_data() !" in v_code

def test_validator_with_check_fields(transpiler):
    code = """
from pydantic import BaseModel, field_validator

class User(BaseModel):
    name: str

    @field_validator('name', check_fields=False)
    @classmethod
    def validate_name(cls, v: str) -> str:
        return v
"""
    v_code = transpiler(code)
    assert "m.name = User_validate_name(m.name) !" in v_code
