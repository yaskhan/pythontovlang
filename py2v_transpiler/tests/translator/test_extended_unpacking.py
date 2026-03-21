"""Tests for Issue #24: Extended unpacking uses invalid indexing.

Parentheses must wrap all arithmetic inside V slice/index expressions so
operator precedence cannot misparse them.

Correct form:
  - Starred slice end:  arr[idx..(arr.len - N)]
  - Trailing element:   arr[(arr.len - offset)]
"""
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


def test_starred_middle_exact_output():
    """first, *middle, last generates the exact safe V destructuring code."""
    code = "first, *middle, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert "first := py_destruct_0[0]" in result
    assert "middle := py_destruct_0[1..(py_destruct_0.len - 1)]" in result
    assert "last := py_destruct_0[(py_destruct_0.len - 1)]" in result


def test_starred_middle_no_unsafe_arithmetic():
    """Bare .len-N] must not appear anywhere in the output."""
    code = "first, *middle, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert ".len-1]" not in result, f"Unsafe '.len-1]':\n{result}"


def test_starred_at_end_uses_open_slice():
    """*rest at end uses open-ended arr[1..] with no arithmetic."""
    code = "first, *rest = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert "first := py_destruct_0[0]" in result
    assert "[1..]" in result


def test_starred_at_start_exact_output():
    """*init, last generates arr[0..(arr.len - 1)] and arr[(arr.len - 1)]."""
    code = "*init, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert "init := py_destruct_0[0..(py_destruct_0.len - 1)]" in result
    assert "last := py_destruct_0[(py_destruct_0.len - 1)]" in result


def test_starred_multiple_trailing_exact_output():
    """a, *b, c, d — slice end and both trailing indices are parenthesized."""
    code = "a, *b, c, d = [1, 2, 3, 4, 5, 6]"
    result = make_translator(code)
    assert "a := py_destruct_0[0]" in result
    assert "b := py_destruct_0[1..(py_destruct_0.len - 2)]" in result
    assert "c := py_destruct_0[(py_destruct_0.len - 2)]" in result
    assert "d := py_destruct_0[(py_destruct_0.len - 1)]" in result
    assert ".len-1]" not in result
    assert ".len-2]" not in result


def test_plain_destructuring_unchanged():
    """Non-starred destructuring is not affected; no starred code appears."""
    code = "a, b, c = [1, 2, 3]"
    result = make_translator(code)
    assert "a" in result
    assert "b" in result
    assert "c" in result
    assert "..]" not in result
