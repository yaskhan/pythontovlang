import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    return translator.visit_Module(tree)

def test_star_call_single():
    code = """
f(*args)
"""
    v_code = transpile(code)
    assert "f(...args)" in v_code

def test_star_call_mixed():
    # V only supports ... as last argument
    code = """
f(a, *b)
"""
    v_code = transpile(code)
    assert "f(a, ...b)" in v_code
