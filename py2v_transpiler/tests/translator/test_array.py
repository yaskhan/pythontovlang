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
    return v_code + "\n" + helpers

def test_array_int():
    source = """
import array
a = array.array('i', [1, 2, 3])
"""
    v_code = translate(source)
    # Check that array.array('i', ...) is mapped to []int
    # V doesn't have 'array' module in the same sense, it uses []T
    # So we expect direct array construction or helper
    assert "a := py_array('i', []int{1, 2, 3})" in v_code

def test_array_float():
    source = """
import array
a = array.array('d', [1.0, 2.0])
"""
    v_code = translate(source)
    assert "a := py_array('d', []f64{1.0, 2.0})" in v_code

def test_array_init_none_typed():
    source = """
from typing import Optional

class Task:
    pass

a: list[Optional[Task]] = [None] * 5
b: list[Task] = [None] * 10
c = [None] * 15
"""
    v_code = translate(source)
    assert "a := []?Task{len: 5, init: none}" in v_code
    assert "b := []?Task{len: 10, init: none}" in v_code
    assert "c := []?Any{len: 15, init: none}" in v_code
