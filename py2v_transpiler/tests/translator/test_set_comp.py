import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    tree = ast.parse(code)
    # Pre-analyze types for robust inference
    analyzer.visit(tree)
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_set_comprehension():
    code = """
s = {x for x in range(5)}
"""
    v_code = transpile(code)
    assert "mut s := map[int]bool{}" in v_code
    assert "for x in 0..5 {" in v_code
    assert "s[x] = true" in v_code

def test_set_comprehension_with_if():
    code = """
s = {x for x in range(10) if x % 2 == 0}
"""
    v_code = transpile(code)
    assert "if x % 2 == 0 {" in v_code
    assert "s[x] = true" in v_code

def test_set_comprehension_zip():
    code = """
s = {x+y for x, y in zip([1,2], [3,4])}
"""
    v_code = transpile(code)
    assert "py_zip_it1_" in v_code
    assert "s[x + y] = true" in v_code

def test_set_comp_string_literal():
    code = "s = {'a' for x in range(5)}"
    v_code = transpile(code)
    assert "map[string]bool" in v_code

def test_set_comp_string_call():
    code = "s = {str(x) for x in range(5)}"
    v_code = transpile(code)
    assert "map[string]bool" in v_code

def test_set_comp_float_op():
    code = "s = {x / 2 for x in range(5)}"
    v_code = transpile(code)
    assert "map[f64]bool" in v_code
