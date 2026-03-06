import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_gen_exp_assignment():
    code = """
g = (x for x in range(5))
"""
    v_code = transpile(code)
    assert "mut g := []int{cap: 5}" in v_code
    # zip iter is not simple prealloc
    assert "for x in 0..5" in v_code
    assert "g << x" in v_code

def test_gen_exp_with_condition():
    code = """
g = (x * 2 for x in range(10) if x % 2 == 0)
"""
    v_code = transpile(code)
    assert "if x % 2 == 0" in v_code
    assert "g << x * 2" in v_code

def test_gen_exp_zip():
    code = """
g = (x + y for x, y in zip([1], [2]))
"""
    v_code = transpile(code)
    assert "mut g := []int{}" in v_code
    # zip iter is not simple prealloc
    assert "py_zip_it1_" in v_code
    assert "g << x + y" in v_code
