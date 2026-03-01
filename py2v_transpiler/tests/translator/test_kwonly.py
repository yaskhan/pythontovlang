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

def test_kwonly_args():
    code = """
def f(a, *, b):
    pass
"""
    v_code = transpile(code)
    assert "fn f(a int, b int)" in v_code

def test_kwonly_multiple():
    code = """
def f(a, *, b, c):
    pass
"""
    v_code = transpile(code)
    assert "fn f(a int, b int, c int)" in v_code

def test_kwonly_with_posonly():
    code = """
def f(a, /, b, *, c):
    pass
"""
    v_code = transpile(code)
    assert "fn f(a int, b int, c int)" in v_code
