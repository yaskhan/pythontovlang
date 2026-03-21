"""Tests for Issue #24: Extended unpacking uses invalid indexing.

Python's `first, *middle, last = [...]` starred assignment must emit
V slice/index expressions with explicit parentheses around arithmetic so
that V's operator precedence cannot misparse them.

Correct form:
  - Starred slice:  arr[idx..(arr.len - N)]   (not arr[idx..arr.len-N])
  - Trailing index: arr[(arr.len - offset)]   (not arr[arr.len-offset])
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


# ---------------------------------------------------------------------------
# first, *middle, last  (starred in the middle)
# ---------------------------------------------------------------------------

def test_starred_middle_slice_has_parentheses():
    """Starred slice for middle must use parenthesized arithmetic."""
    code = "first, *middle, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    # Safe form: idx..(arr.len - N)
    assert ".len - 1)" in result, f"Expected '(arr.len - 1)' in slice:\n{result}"
    # Must NOT use the unsafe bare form
    assert ".len-1]" not in result, f"Unsafe '.len-1]' found:\n{result}"


def test_starred_middle_trailing_index_has_parentheses():
    """Trailing element (last) must use parenthesized index arithmetic."""
    code = "first, *middle, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    # Safe trailing index: ends with .len - 1)] (the var name precedes .len)
    assert ".len - 1)]" in result, (
        f"Expected parenthesized trailing index (containing '.len - 1)]'):\n{result}"
    )
    assert ".len-1]" not in result, f"Unsafe '.len-1]' found in trailing index:\n{result}"


def test_starred_middle_first_element():
    """first must be assigned from index 0."""
    code = "first, *middle, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert "[0]" in result, f"Expected '[0]' index for first:\n{result}"
    assert "first :=" in result, f"Expected 'first :=' in:\n{result}"


def test_starred_middle_all_variables_present():
    """All three variables (first, middle, last) must be assigned."""
    code = "first, *middle, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert "first :=" in result, f"Expected 'first :=' in:\n{result}"
    assert "middle :=" in result, f"Expected 'middle :=' in:\n{result}"
    assert "last :=" in result, f"Expected 'last :=' in:\n{result}"


# ---------------------------------------------------------------------------
# first, *rest  (starred at end — trailing=0, no arithmetic needed)
# ---------------------------------------------------------------------------

def test_starred_at_end_uses_open_slice():
    """*rest at end uses arr[idx..] — no arithmetic, so no parentheses needed."""
    code = "first, *rest = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert "first :=" in result, f"Expected 'first :=':\n{result}"
    assert "rest :=" in result, f"Expected 'rest :=':\n{result}"
    # Open-ended slice for rest
    assert "[1..]" in result, f"Expected open-ended slice '[1..]':\n{result}"


# ---------------------------------------------------------------------------
# *init, last  (starred at start)
# ---------------------------------------------------------------------------

def test_starred_at_start_slice_has_parentheses():
    """*init at start uses arr[0..(arr.len - 1)] — parenthesized."""
    code = "*init, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    assert "init :=" in result, f"Expected 'init :=':\n{result}"
    assert "last :=" in result, f"Expected 'last :=':\n{result}"
    assert ".len - 1)" in result, f"Expected parenthesized arithmetic:\n{result}"
    assert ".len-1]" not in result, f"Unsafe '.len-1]' found:\n{result}"


# ---------------------------------------------------------------------------
# a, *b, c, d  (multiple trailing elements)
# ---------------------------------------------------------------------------

def test_starred_multiple_trailing_elements():
    """Multiple elements after * — each uses parenthesized arithmetic."""
    code = "a, *b, c, d = [1, 2, 3, 4, 5, 6]"
    result = make_translator(code)
    assert "a :=" in result, f"Expected 'a :=':\n{result}"
    assert "b :=" in result, f"Expected 'b :=':\n{result}"
    assert "c :=" in result, f"Expected 'c :=':\n{result}"
    assert "d :=" in result, f"Expected 'd :=':\n{result}"
    # Slice for b: idx..(arr.len - 2)
    assert ".len - 2)" in result, f"Expected '(arr.len - 2)' in slice:\n{result}"
    # Index for c: ends with .len - 2)] 
    assert ".len - 2)]" in result, (
        f"Expected parenthesized '.len - 2)' for c:\n{result}"
    )
    # Index for d: ends with .len - 1)]
    assert ".len - 1)]" in result, (
        f"Expected parenthesized '.len - 1)' for d:\n{result}"
    )
    # No unsafe bare arithmetic
    assert ".len-1]" not in result, f"Unsafe '.len-1]' found:\n{result}"
    assert ".len-2]" not in result, f"Unsafe '.len-2]' found:\n{result}"


# ---------------------------------------------------------------------------
# Regression: no starred (plain destructuring unchanged)
# ---------------------------------------------------------------------------

def test_plain_destructuring_unchanged():
    """Non-starred tuple/list destructuring must be unaffected by the fix.

    The transpiler optimises `a, b, c = [1, 2, 3]` into a multi-assign
    `a, b, c := 1, 2, 3` when the lengths match. We only verify the three
    variables are present and no starred-unpacking code was introduced.
    """
    code = "a, b, c = [1, 2, 3]"
    result = make_translator(code)
    assert "a" in result, f"Expected 'a' in result:\n{result}"
    assert "b" in result, f"Expected 'b' in result:\n{result}"
    assert "c" in result, f"Expected 'c' in result:\n{result}"
    # No starred slice should appear
    assert "..]" not in result, f"Unexpected starred slice:\n{result}"
    assert "py_loop_completed" not in result, f"No loop flag expected:\n{result}"


# ---------------------------------------------------------------------------
# Semantic correctness (structure of generated code)
# ---------------------------------------------------------------------------

def test_starred_middle_slice_range_correctness():
    """Verify the slice range is semantically correct: idx..(len - trailing)."""
    code = "first, *middle, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    # middle is at starred_idx=1, trailing=1
    # Expected: arr[1..(arr.len - 1)]
    assert "[1..(" in result, f"Expected '[1..(' in result:\n{result}"


def test_starred_start_slice_range_correctness():
    """*init,last: slice starts at 0, ends at (len-1)."""
    code = "*init, last = [1, 2, 3, 4, 5]"
    result = make_translator(code)
    # starred_idx=0, trailing=1: arr[0..(arr.len - 1)]
    assert "[0..(" in result, f"Expected '[0..(' in result:\n{result}"
