"""Tests for Issue #23: Slice assignment with step not supported.

Python's `lst[::2] = [...]` assigns to every N-th element. V has no native
stepped slice assignment, so the translator must emit an explicit for-loop.
Step=None and step=1 keep the existing delete_many/insert_many path.
Negative or non-constant steps fall back with an LLM comment.
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


def test_step2_emits_for_loop():
    """lst[::2] = [...] must emit a for-loop incrementing by 2."""
    result = transpile("lst[::2] = [100, 200, 300]")
    assert "py_step_rhs_0 := [100, 200, 300]" in result
    assert "mut py_step_i_0 := 0" in result
    assert "py_step_idx_0 := 0; py_step_idx_0 < lst.len; py_step_idx_0 += 2" in result
    assert "lst[py_step_idx_0] = py_step_rhs_0[py_step_i_0]" in result
    assert "py_step_i_0++" in result


def test_step2_no_delete_many():
    """Step-loop must not fall through to delete_many/insert_many."""
    result = transpile("lst[::2] = [100, 200, 300]")
    assert "delete_many" not in result
    assert "insert_many" not in result


def test_step3_with_start_stop():
    """lst[1:8:3] = [...] emits a for-loop from 1 to 8, step 3."""
    result = transpile("lst[1:8:3] = [10, 20, 30]")
    assert "py_step_rhs_0 := [10, 20, 30]" in result
    assert "py_step_idx_0 := 1; py_step_idx_0 < 8; py_step_idx_0 += 3" in result
    assert "lst[py_step_idx_0] = py_step_rhs_0[py_step_i_0]" in result
    assert "delete_many" not in result


def test_step1_uses_delete_insert():
    """lst[::1] = [...] (step=1) keeps the delete_many/insert_many path."""
    result = transpile("lst[::1] = [1, 2, 3]")
    assert "delete_many" in result
    assert "insert_many" in result
    assert "py_step_idx" not in result


def test_no_step_uses_delete_insert():
    """lst[1:5] = [...] (no step) keeps the delete_many/insert_many path."""
    result = transpile("lst[1:5] = [1, 2, 3]")
    assert "delete_many" in result
    assert "insert_many" in result
    assert "py_step_idx" not in result


def test_negative_step_emits_llm_comment():
    """lst[::-1] = [...] emits an LLM comment (negative step, out of scope)."""
    result = transpile("lst[::-1] = [1, 2, 3]")
    assert "//##LLM@@" in result
    assert "Negative step" in result


def test_loop_guard_break_present():
    """The safety guard 'if py_step_i >= rhs.len { break }' must appear."""
    result = transpile("lst[::2] = [100, 200, 300]")
    assert "if py_step_i_0 >= py_step_rhs_0.len { break }" in result


def test_step_default_start_is_zero():
    """lst[::3] = [...] with no explicit start defaults to 0."""
    result = transpile("lst[::3] = [1, 2, 3]")
    assert "py_step_idx_0 := 0;" in result


def test_step_default_stop_is_len():
    """lst[::4] = [...] with no explicit stop defaults to lst.len."""
    result = transpile("lst[::4] = [1, 2]")
    assert "py_step_idx_0 < lst.len" in result


def test_non_constant_step_emits_llm_comment():
    """lst[::n] = [...] (variable step) emits an LLM comment fallback."""
    result = transpile("lst[::n] = [1, 2, 3]")
    assert "//##LLM@@" in result
    assert "Non-constant step" in result
