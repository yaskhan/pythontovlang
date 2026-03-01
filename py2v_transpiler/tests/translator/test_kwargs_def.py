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

def test_kwargs_def_only():
    code = """
def f(**kwargs):
    pass
"""
    v_code = transpile(code)
    assert "fn f(kwargs map[string]string)" in v_code

def test_kwargs_def_mixed():
    code = """
def f(a, **kwargs):
    pass
"""
    v_code = transpile(code)
    assert "fn f(a int, kwargs map[string]string)" in v_code
