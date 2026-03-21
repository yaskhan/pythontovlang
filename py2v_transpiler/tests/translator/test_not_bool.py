import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference


def make_translator(code: str):
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = parser.parse(code)
    analyzer.analyze(tree)
    return translator.visit_Module(tree)


def test_not_bool_variable_generates_bang_not_eq_zero():
    code = """
x = False
if not x:
    print('x is False')
"""
    result = make_translator(code)
    assert "!x" in result, f"Expected '!x' but got: {result}"
    assert "x == 0" not in result, f"Should not generate 'x == 0' for bool: {result}"


def test_not_true_variable():
    code = """
flag = True
if not flag:
    print('flag is False')
"""
    result = make_translator(code)
    assert "!flag" in result, f"Expected '!flag' but got: {result}"
    assert "flag == 0" not in result, f"Should not generate 'flag == 0' for bool: {result}"


def test_not_int_variable_generates_eq_zero():
    code = """
n = 5
if not n:
    print('n is zero')
"""
    result = make_translator(code)
    assert "n == 0" in result, f"Expected 'n == 0' for int but got: {result}"
