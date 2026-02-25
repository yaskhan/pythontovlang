import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    return translator.visit_Module(tree)

def test_chained_compare_int():
    code = """
if 1 < x < 10:
    pass
"""
    v_code = transpile(code)
    assert "(1 < x) && (x < 10)" in v_code

def test_chained_compare_multiple():
    code = """
if a < b <= c > d:
    pass
"""
    v_code = transpile(code)
    assert "(a < b) && (b <= c) && (c > d)" in v_code

def test_chained_compare_is():
    code = """
if x is not None is y:
    pass
"""
    # Note: 'x is not None' -> 'x != none', so middle is 'none'. 'none is y'?
    # Actually Python 'x is not None is y' is parsed as (x is not None) and (None is y).
    # V: (x != none) && (none == y)
    v_code = transpile(code)
    assert "(x != none) && (none == y)" in v_code

def test_chained_compare_expressions():
    code = """
if x + 1 < y * 2 < z:
    pass
"""
    v_code = transpile(code)
    # Binary operations are usually not parenthesized by default in visit_BinOp unless precedence requires it,
    # but my new code wraps comparators in parentheses.
    # The comparators are 'x + 1', 'y * 2', 'z'.
    # Result should be (x + 1 < y * 2) && (y * 2 < z).
    assert "(x + 1 < y * 2) && (y * 2 < z)" in v_code
