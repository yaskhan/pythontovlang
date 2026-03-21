import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def translate(source):
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer)
    return visitor.visit_Module(tree)

def test_global_constants_compile_time():
    source = """
from typing import Final

DEFAULT_WIDTH = 100
DEFAULT_HEIGHT: Final = 200
"""
    v_code = translate(source)
    assert "const DEFAULT_WIDTH = 100" in v_code
    assert "const DEFAULT_HEIGHT = 200" in v_code

def test_global_constants_runtime():
    source = """
class Vector:
    def __init__(self, x, y, z):
        pass

VECTOR_ZERO = Vector(0, 0, 0)
"""
    v_code = translate(source)
    assert "VECTOR_ZERO = new_vector(0, 0, 0)" in v_code

def test_global_constants_assignment():
    source = """
VECTOR_ONE = Vector(1, 1, 1)
"""
    v_code = translate(source)
    assert "__global VECTOR_ONE" in v_code

def test_global_constants_public():
    source = """
from typing import Final

__all__ = ["DEFAULT_WIDTH"]

DEFAULT_WIDTH = 100
DEFAULT_HEIGHT: Final = 200
"""
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    translator.config = type("TranspilerConfig", (), {"export_all": False})()
    translator.module_all = ["DEFAULT_WIDTH"]

    v_code = translator.visit_Module(tree)
    v_code = translator.emitter.emit()
    assert "pub const DEFAULT_WIDTH = 100" in v_code
