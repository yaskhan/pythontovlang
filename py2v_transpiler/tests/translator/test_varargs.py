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
    assert "fn f(a Any, b ...int)" in v_code

def test_varargs_with_type_annotation():
    code = """
def f(*args: str):
    pass
"""
    v_code = transpile(code)
    assert "fn f(args ...string)" in v_code

def test_kwargs_basic():
    code = """
def f(**kwargs):
    pass
f(a=1, b=2)
"""
    v_code = transpile(code)
    assert "f({'a': 1, 'b': 2})" in v_code

def test_nested_function_leakage_prevention():
    code = """
def test1():
    def greet():
        pass
    greet()

def test2():
    def greet(x):
        pass
    greet(1)
"""
    v_code = transpile(code)
    assert "greet()" in v_code
    assert "greet(1)" in v_code

def test_varargs_list_annotation():
    code = """
from typing import List
def f(*args: List[int]):
    pass
"""
    v_code = transpile(code)
    # The fix should strip [] from []int to get ...int
    assert "fn f(args ...int)" in v_code

def test_lambda_varargs():
    code = "sum_all = lambda *args: sum(args)"
    v_code = transpile(code)
    assert "fn (args ...int) Any" in v_code
