"""Tests for lambda i=i capture-by-value pattern (Issue #35)."""
import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference


def make_translator(code: str) -> str:
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = parser.parse(code)
    analyzer.analyze(tree)
    return translator.visit_Module(tree)


def test_lambda_default_arg_becomes_capture():
    """lambda x, i=i: x + i should capture i in [i], not list i as parameter."""
    code = "f = lambda x, i=i: x + i"
    result = make_translator(code)
    # i must appear as a closure capture, not as a parameter
    assert "[i]" in result, f"Expected '[i]' capture in: {result}"
    # The lambda parameter list should be just (x int), not (x int, i int)
    assert "fn [i] (x int)" in result, f"Expected 'fn [i] (x int)' in: {result}"


def test_lambda_default_only_strips_self_capture():
    """Only i=i (same name) is treated as capture; j=0 is a normal default."""
    code = "f = lambda x, j=0: x + j"
    result = make_translator(code)
    # j has default 0 (not ast.Name 'j'), so it stays as a parameter
    assert "j int" in result, f"Expected 'j int' param in: {result}"
    assert "[j]" not in result, f"Should not capture j: {result}"


def test_lambda_list_comp_capture_pattern():
    """[lambda x, i=i: x+i for i in range(5)] — each lambda captures i by value."""
    code = "funcs = [lambda x, i=i: x + i for i in range(5)]"
    result = make_translator(code)
    # Each lambda should use [i] capture
    assert "[i]" in result, f"Expected closure capture '[i]' in: {result}"
    # Parameter list should only have x, not i
    assert "fn [i] (x int)" in result, f"Expected 'fn [i] (x int)' in: {result}"
    # Array type should NOT be []int
    assert "[]int{cap:" not in result, f"Array should not be []int: {result}"


def test_lambda_multi_default_capture():
    """lambda x, i=i, j=j: x+i+j — both i and j become captures."""
    code = "f = lambda x, i=i, j=j: x + i + j"
    result = make_translator(code)
    assert "[i" in result and "j" in result, f"Expected i,j captures in: {result}"
    # x should remain a parameter
    assert "x int" in result, f"Expected 'x int' param in: {result}"
