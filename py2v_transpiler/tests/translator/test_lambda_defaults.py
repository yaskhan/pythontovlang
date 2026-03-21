"""Tests for Issue #32: lambda default values lost.

When `power = lambda x, n=2: x**n` is assigned, the default `n=2` must be
tracked so that `power(5)` correctly emits `power(5, 2)` in V.
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


def test_lambda_numeric_default_injected():
    """power = lambda x, n=2: x**n; power(5) must inject the default → power(5, 2)."""
    code = "power = lambda x, n=2: x ** n\nprint(power(5))"
    result = make_translator(code)
    assert "power(5, 2)" in result, f"Expected 'power(5, 2)' in:\n{result}"


def test_lambda_explicit_arg_not_overridden():
    """power = lambda x, n=2: x**n; power(3, 3) must stay power(3, 3), not inject default."""
    code = "power = lambda x, n=2: x ** n\nprint(power(3, 3))"
    result = make_translator(code)
    assert "power(3, 3)" in result, f"Expected 'power(3, 3)' in:\n{result}"
    assert "power(3, 3, 2)" not in result, f"Default must not be double-injected: {result}"


def test_lambda_string_default_injected():
    """sep default injection for a string default value."""
    code = "join_fn = lambda items, sep='-': sep.join(items)\nprint(join_fn(['a', 'b']))"
    result = make_translator(code)
    assert "join_fn(" in result
    assert "'-'" in result or '"-"' in result, f"Expected sep default '-' in:\n{result}"


def test_lambda_no_default_unchanged():
    """lambda with no defaults should not be affected."""
    code = "add = lambda x, y: x + y\nprint(add(1, 2))"
    result = make_translator(code)
    assert "add(1, 2)" in result, f"Expected 'add(1, 2)' in:\n{result}"


def test_lambda_capture_not_injected_as_default():
    """i=i is a capture-by-value pattern (Issue #35), NOT a call-site default.

    `f = lambda x, i=i: x + i; f(3)` must emit `f(3)`, NOT `f(3, i)`.
    The i=i arg becomes a V closure capture [i], not a parameter.
    """
    code = "i = 5\nf = lambda x, i=i: x + i\nprint(f(3))"
    result = make_translator(code)
    # i=i becomes capture [i]; f has only one real parameter x
    assert "fn [i]" in result or "fn[i]" in result, f"Expected closure capture [i] in:\n{result}"
    assert "f(3)" in result, f"Expected 'f(3)' call in:\n{result}"
    assert "f(3, i)" not in result, f"i=i capture must not be injected at call site: {result}"


def test_lambda_multiple_defaults_injected():
    """lambda with multiple defaults: all missing ones should be injected."""
    code = "fn = lambda x, a=1, b=2: x + a + b\nprint(fn(10))"
    result = make_translator(code)
    assert "fn(10, 1, 2)" in result, f"Expected 'fn(10, 1, 2)' in:\n{result}"


def test_lambda_partial_explicit_args():
    """lambda with multiple defaults: only missing ones injected."""
    code = "fn = lambda x, a=1, b=2: x + a + b\nprint(fn(10, 5))"
    result = make_translator(code)
    assert "fn(10, 5, 2)" in result, f"Expected 'fn(10, 5, 2)' in:\n{result}"
