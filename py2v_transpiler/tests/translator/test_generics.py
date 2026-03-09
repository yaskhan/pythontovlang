import ast
import sys
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile_source(source_code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source_code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

def test_generic_inheritance_multi_params():
    source = """
from typing import Generic, TypeVar

K = TypeVar('K')
V = TypeVar('V')

class Base(Generic[K, V]):
    pass

class Derived(Base[K, V]):
    pass
"""
    v_code = transpile_source(source)
    assert "struct Base[K, V]" in v_code
    assert "struct Derived[K, V]" in v_code
    # Multi-parameter generic bases should use named field
    assert "_base_Base Base[K, V]" in v_code

def test_generic_inheritance_single_param():
    source = """
from typing import Generic, TypeVar

T = TypeVar('T')

class Base(Generic[T]):
    pass

class Derived(Base[T]):
    pass
"""
    v_code = transpile_source(source)
    assert "struct Base[T]" in v_code
    assert "struct Derived[T]" in v_code
    # Single-parameter generic bases should use anonymous embedding
    assert "    Base[T]" in v_code

def test_generic_inheritance_super_init():
    source = """
from typing import Generic, TypeVar

T = TypeVar('T')

class Base(Generic[T]):
    def __init__(self, x: T):
        self.x = x

class Derived(Base[int]):
    def __init__(self, x: int, y: int):
        super().__init__(x)
        self.y = y
"""
    v_code = transpile_source(source)
    assert "struct Derived {" in v_code
    # Single-parameter generic base -> anonymous embedding
    assert "    Base[int]" in v_code
    # Anonymous embedding initialization in V uses base name
    assert "self.Base = new_base(x)" in v_code

def test_non_generic_inheritance():
    source = """
class Base:
    pass

class Derived(Base):
    pass
"""
    v_code = transpile_source(source)
    assert "struct Base" in v_code
    assert "struct Derived" in v_code
    # Non-generic should use anonymous embedding (indented name on its own line)
    assert "    Base" in v_code

@pytest.mark.skipif(sys.version_info < (3, 12), reason="Modern generic syntax [T] requires Python 3.12+")
def test_modern_generic_syntax():
    source = """
class Base[T]:
    pass

class Derived[T](Base[T]):
    pass
"""
    v_code = transpile_source(source)
    assert "struct Base[T]" in v_code
    assert "struct Derived[T]" in v_code
    # Single-parameter generic base -> anonymous embedding
    assert "    Base[T]" in v_code

def test_generic_inheritance_multi_params_super_init():
    source = """
from typing import Generic, TypeVar

K = TypeVar('K')
V = TypeVar('V')

class Base(Generic[K, V]):
    def __init__(self, k: K, v: V):
        self.k = k
        self.v = v

class Derived(Base[str, int]):
    def __init__(self, k: str, v: int):
        super().__init__(k, v)
"""
    v_code = transpile_source(source)
    assert "struct Derived {" in v_code
    # Multi-parameter generic base -> named field
    assert "_base_Base Base[string, int]" in v_code
    assert "self._base_Base = new_base(k, v)" in v_code
