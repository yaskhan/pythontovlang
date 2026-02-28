import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    return translator.visit_Module(tree)

def test_kwargs_def_only():
    code = """
def f(**kwargs):
    pass
"""
    v_code = transpile(code)
    assert "fn f(kwargs map[string]Any)" in v_code

def test_kwargs_def_mixed():
    code = """
def f(a, **kwargs):
    pass
"""
    v_code = transpile(code)
    assert "fn f(a int, kwargs map[string]Any)" in v_code
