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

def test_config_class(transpiler):
    code = """
from pydantic import BaseModel

class User(BaseModel):
    name: str

    class Config:
        populate_by_name = True
        alias_generator = str.upper
"""
    v_code = transpiler(code)
    # Check if config is processed (even if just as comments or specific V tags)
    assert "// Pydantic Config: populate_by_name = true" in v_code
    assert "// Pydantic Config: alias_generator = str.upper" in v_code

def test_config_dict(transpiler):
    code = """
from pydantic import BaseModel, ConfigDict

class User(BaseModel):
    model_config = ConfigDict(extra='forbid', str_to_lower=True)
    name: str
"""
    v_code = transpiler(code)
    assert "// Pydantic Config: extra = 'forbid'" in v_code
    assert "// Pydantic Config: str_to_lower = true" in v_code

def test_config_validation_options(transpiler):
    code = """
from pydantic import BaseModel, ConfigDict

class User(BaseModel):
    model_config = ConfigDict(validate_assignment=True, strict=True)
    name: str
"""
    v_code = transpiler(code)
    assert "// Pydantic Config: validate_assignment = true" in v_code
    assert "// Pydantic Config: strict = true" in v_code

def test_config_string_transformation(transpiler):
    code = """
from pydantic import BaseModel, ConfigDict

class User(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, str_max_length=100)
    name: str
"""
    v_code = transpiler(code)
    assert "// Pydantic Config: str_strip_whitespace = true" in v_code
    assert "// Pydantic Config: str_max_length = 100" in v_code
