"""Tests for Issue #13: assert message was silently dropped.

V 0.4.x/0.5.x supports `assert cond, "message"`. When the Python source
includes an assert message, the translator must forward it.
"""
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.config import TranspilerConfig


def transpile(code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer, TranspilerConfig())
    return visitor.visit_Module(tree)


def test_assert_no_message():
    """Plain assert without message emits 'assert cond' unchanged."""
    result = transpile("assert x == 5")
    assert "assert x == 5" in result
    assert "assert x == 5," not in result


def test_assert_with_string_message():
    """assert cond, 'msg' must emit 'assert cond, msg'."""
    result = transpile('assert x == 5, "x should be 5"')
    assert "assert x == 5, 'x should be 5'" in result


def test_assert_with_fstring_message():
    """assert cond, f'val={v}' must include the interpolated V string."""
    result = transpile('assert x == 5, f"val={x}"')
    assert "assert x == 5, 'val=${x}'" in result


def test_assert_false_no_message():
    """assert False (no message) keeps the plain form."""
    result = transpile("assert False")
    assert "assert" in result
    assert "assert False" in result or "assert false" in result.lower()


def test_assert_message_not_dropped():
    """Regression: original bug was message silently absent."""
    result = transpile('assert x == 5, "x should be 5"')
    assert "x should be 5" in result
