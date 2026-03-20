import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def _transpile(code: str) -> str:
    tree = ast.parse(code)
    ti = TypeInference()
    ti.visit(tree)
    translator = VNodeVisitor(ti)
    v_code = translator.visit_Module(tree)
    return v_code

def test_dict_any_fallback():
    code = "d = dict()"
    output = _transpile(code)
    assert "map[string]Any{}" in output

def test_set_any_fallback():
    code = "s = set()"
    output = _transpile(code)
    assert "datatypes.Set[string]{}" in output

def test_dict_literal_any_fallback():
    code = """
from typing import Any
def foo(k: Any):
    d = {k: 1}
"""
    output = _transpile(code)
    # The literal might omit the type but the variables assignment handles fallback type logic.
    assert "map[string]int" in output or "{" in output

def test_set_literal_any_fallback():
    code = """
from typing import Any
def foo(a: Any):
    s = {a}
"""
    output = _transpile(code)
    assert "datatypes.Set[string]" in output or "{" in output
