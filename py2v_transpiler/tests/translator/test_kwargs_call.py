import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    return translator.visit_Module(tree)

def test_kwargs_call_only():
    code = """
d = {}
f(**d)
"""
    v_code = transpile(code)
    assert "f(d)" in v_code

def test_kwargs_call_mixed():
    code = """
d = {}
f(1, **d)
"""
    v_code = transpile(code)
    assert "f(1, d)" in v_code
