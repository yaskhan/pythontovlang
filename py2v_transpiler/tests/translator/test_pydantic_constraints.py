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

def test_numeric_constraints(transpiler):
    code = """
from pydantic import BaseModel, Field

class NumericModel(BaseModel):
    multiple: int = Field(multiple_of=5)
    gt_lt: float = Field(gt=0, lt=100)
    ge_le: int = Field(ge=1, le=10)
"""
    v_code = transpiler(code)
    assert "if m.multiple % 5 != 0 { return error('Validation Error: multiple must be a multiple of 5') }" in v_code
    assert "if m.gt_lt <= 0 { return error('Validation Error: gt_lt must be greater than 0') }" in v_code
    assert "if m.gt_lt >= 100 { return error('Validation Error: gt_lt must be less than 100') }" in v_code

def test_string_constraints(transpiler):
    code = """
from pydantic import BaseModel, Field

class StringModel(BaseModel):
    pattern: str = Field(pattern=r'^[a-z]+$')
    lengths: str = Field(min_length=3, max_length=10)
"""
    v_code = transpiler(code)
    # V's regex support would be via pcre or similar.
    # For now, let's see how the transpiler handles 'pattern' (it was called 'regex' in Pydantic v1)
    assert "if !m.pattern.match_full('^[a-z]+$') { return error('Validation Error: pattern must match regex ^[a-z]+$') }" in v_code
    assert "if m.lengths.len < 3 { return error('Validation Error: lengths length must be >= 3') }" in v_code
    assert "if m.lengths.len > 10 { return error('Validation Error: lengths length must be <= 10') }" in v_code

def test_collection_constraints(transpiler):
    code = """
from typing import List
from pydantic import BaseModel, Field

class CollectionModel(BaseModel):
    items: List[int] = Field(min_length=1, max_length=5)
"""
    v_code = transpiler(code)
    assert "if m.items.len < 1 { return error('Validation Error: items length must be >= 1') }" in v_code
    assert "if m.items.len > 5 { return error('Validation Error: items length must be <= 5') }" in v_code

def test_default_factory(transpiler):
    code = """
from typing import List
from pydantic import BaseModel, Field

def get_default_list():
    return [1, 2, 3]

class FactoryModel(BaseModel):
    items: List[int] = Field(default_factory=get_default_list)
"""
    v_code = transpiler(code)
    # Pydantic's default_factory should map to a V default value call
    assert "items []int = get_default_list()" in v_code

def test_numeric_constraints_edge(transpiler):
    code = """
from pydantic import BaseModel, Field

class NumericModel(BaseModel):
    gt: int = Field(gt=10)
    ge: int = Field(ge=10)
    lt: int = Field(lt=10)
    le: int = Field(le=10)
"""
    v_code = transpiler(code)
    assert "if m.gt <= 10" in v_code
    assert "if m.ge < 10" in v_code
    assert "if m.lt >= 10" in v_code
    assert "if m.le > 10" in v_code

def test_string_constraints_min_max(transpiler):
    code = """
from pydantic import BaseModel, Field

class StringModel(BaseModel):
    s: str = Field(min_length=5, max_length=15)
"""
    v_code = transpiler(code)
    assert "if m.s.len < 5" in v_code
    assert "if m.s.len > 15" in v_code

def test_list_constraints(transpiler):
    code = """
from typing import List
from pydantic import BaseModel, Field

class ListModel(BaseModel):
    l: List[str] = Field(min_length=2, max_length=4)
"""
    v_code = transpiler(code)
    assert "if m.l.len < 2" in v_code
    assert "if m.l.len > 4" in v_code
