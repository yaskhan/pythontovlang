import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    tree = ast.parse(code)
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_kwargs_call_only():
    code = """
d = {}
f(**d)
"""
    v_code = transpile(code)
    assert "//##LLM@@" in v_code
    assert "d" in v_code

def test_kwargs_call_mixed():
    code = """
d = {}
f(1, **d)
"""
    v_code = transpile(code)
    assert "//##LLM@@" in v_code
    assert "d" in v_code

def test_posonly_args_with_keyword_call():
    code = """
def func(a, b, c, d):
    pass

func(1, 2, c=3, d=4)
"""
    v_code = transpile(code)
    assert "func(1, 2, 3, 4)" in v_code

def test_posonly_separator_with_keyword_call():
    code = """
def func(a, b, /, c, d):
    pass

func(1, 2, c=3, d=4)
"""
    v_code = transpile(code)
    assert "func(1, 2, 3, 4)" in v_code
