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

def test_varargs_only():
    code = """
def f(*args):
    pass
"""
    v_code = transpile(code)
    assert "fn f(args ...int)" in v_code

def test_varargs_mixed():
    code = """
def f(a, *b):
    pass
"""
    v_code = transpile(code)
    assert "fn f(a int, b ...int)" in v_code

def test_varargs_with_type_annotation():
    code = """
def f(*args: str):
    pass
"""
    # Assuming annotation maps to ...string
    v_code = transpile(code)
    assert "fn f(args ...string)" in v_code
