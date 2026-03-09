import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return translator.emitter.emit()

def test_global_constants_compile_time():
    source = """
from typing import Final

DEFAULT_WIDTH = 100
DEFAULT_HEIGHT: Final = 200
"""
    v_code = translate(source)
    assert "const (" in v_code
    assert "default_width = 100" in v_code
    assert "default_height = 200" in v_code
    # They should not be in main
    main_body_start = v_code.find("fn main() {")
    assert "DEFAULT_WIDTH" not in v_code[main_body_start:]
    assert "DEFAULT_HEIGHT" not in v_code[main_body_start:]

def test_global_constants_runtime():
    source = """
from typing import Final

Vector_ZERO: Final = Vector(0, 0, 0)
"""
    v_code = translate(source)
    # Because Vector is not compile time evaluable, it should be in __global and initialized in init()
    assert "__global vector_zero Any" in v_code

    assert "fn init() {" in v_code
    assert "vector_zero = Vector(0, 0, 0)" in v_code

    # It should not be in main
    main_body_start = v_code.find("fn main() {")
    assert "vector_zero = Vector(0, 0, 0)" not in v_code[main_body_start:]

def test_global_constants_assignment():
    source = """
VECTOR_ONE = Vector(1, 1, 1)
"""
    v_code = translate(source)
    # Uppercase but runtime initialization
    assert "__global vector_one Any" in v_code

    assert "fn init() {" in v_code
    assert "vector_one = Vector(1, 1, 1)" in v_code

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
    helpers = translator.emitter.emit_helpers()
    v_code = translator.emitter.emit()
    assert "pub const (" in v_code
    assert "default_width = 100" in v_code
    assert "const (" in v_code
    assert "default_height = 200" in v_code
