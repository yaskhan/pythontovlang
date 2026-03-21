"""Tests for Issue #29: for/else and while/else semantics.

Python's for/else and while/else: the else clause runs only if the loop
completed without hitting a break. The transpiler handles this via a
`py_loop_completed_N` boolean flag that is set to false before each break.

When there is no break at all in the loop body, the else is emitted
unconditionally — which is correct Python semantics.
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
# for/else — no break (else always runs, no flag needed)
# ---------------------------------------------------------------------------

def test_for_else_no_break_runs_unconditionally():
    """No break → else is emitted after loop without any flag guard.

    This is correct: Python also always runs the else when there is no break.
    """
    code = "for i in range(3):\n    print(i)\nelse:\n    print('done')"
    result = make_translator(code)
    # Else block present unconditionally
    assert "println('done')" in result, f"Expected else block in:\n{result}"
    # No flag needed when no break exists
    assert "py_loop_completed" not in result, f"No flag expected when no break:\n{result}"


def test_for_else_no_break_appears_after_loop():
    """Else block must appear AFTER the closing brace of the for loop.

    Uses find() (first `}`) which is the for-loop close, not the outer
    function close brace.
    """
    code = "for i in range(3):\n    print(i)\nelse:\n    print('after')"
    result = make_translator(code)
    # The first } closes the for loop; else body comes after it
    loop_close = result.find("}")
    else_pos = result.find("println('after')")
    assert else_pos > loop_close, f"Else must come after loop closing brace:\n{result}"


# ---------------------------------------------------------------------------
# for/else — with break (flag mechanism required)
# ---------------------------------------------------------------------------

def test_for_else_break_in_if_uses_flag():
    """Break inside an if → py_loop_completed flag created and guarded."""
    code = (
        "for i in range(10):\n"
        "    if i == 5:\n"
        "        break\n"
        "else:\n"
        "    print('not found')"
    )
    result = make_translator(code)
    assert "py_loop_completed" in result, f"Expected flag in:\n{result}"
    # Flag set to false before break
    assert "= false" in result, f"Expected flag set to false before break:\n{result}"
    # Else guarded by flag check
    assert "if py_loop_completed" in result, f"Expected flag guard for else:\n{result}"
    assert "println('not found')" in result, f"Expected else body in:\n{result}"


def test_for_else_break_flag_set_before_break():
    """Ensure the flag=false assignment appears before the break statement."""
    code = (
        "for i in range(10):\n"
        "    if i == 5:\n"
        "        break\n"
        "else:\n"
        "    print('else')"
    )
    result = make_translator(code)
    flag_false_pos = result.find("= false")
    break_pos = result.find("break")
    assert flag_false_pos < break_pos, (
        f"Flag must be set to false BEFORE break:\n{result}"
    )


def test_for_else_multiple_breaks_all_set_flag():
    """Multiple break paths must all set the flag to false."""
    code = (
        "for i in range(10):\n"
        "    if i == 3:\n"
        "        break\n"
        "    if i == 7:\n"
        "        break\n"
        "else:\n"
        "    print('done')"
    )
    result = make_translator(code)
    assert result.count("= false") == 2, (
        f"Expected two flag=false assignments (one per break):\n{result}"
    )
    assert "if py_loop_completed" in result, f"Expected flag guard:\n{result}"


def test_for_else_break_in_try_uses_flag():
    """Break inside a try block must trigger the flag mechanism."""
    code = (
        "for i in range(10):\n"
        "    try:\n"
        "        if i == 5:\n"
        "            break\n"
        "    except Exception:\n"
        "        pass\n"
        "else:\n"
        "    print('done')"
    )
    result = make_translator(code)
    assert "py_loop_completed" in result, f"Expected flag for break inside try:\n{result}"
    assert "= false" in result, f"Expected flag=false in:\n{result}"
    assert "if py_loop_completed" in result, f"Expected flag guard:\n{result}"


def test_for_else_break_in_with_uses_flag():
    """Break inside a with statement must trigger the flag mechanism."""
    code = (
        "import contextlib\n"
        "for i in range(10):\n"
        "    with contextlib.suppress(Exception):\n"
        "        if i == 5:\n"
        "            break\n"
        "else:\n"
        "    print('done')"
    )
    result = make_translator(code)
    assert "py_loop_completed" in result, f"Expected flag for break inside with:\n{result}"
    assert "if py_loop_completed" in result, f"Expected flag guard:\n{result}"


# ---------------------------------------------------------------------------
# Nested loops — inner break must NOT affect outer else
# ---------------------------------------------------------------------------

def test_for_else_inner_break_does_not_affect_outer_else():
    """Break in inner for loop must not set the outer loop's flag.

    The outer else should run unconditionally (no flag) because _has_break
    correctly stops recursion at inner ast.For nodes.
    """
    code = (
        "for i in range(3):\n"
        "    for j in range(3):\n"
        "        if j == 1:\n"
        "            break\n"
        "else:\n"
        "    print('outer done')"
    )
    result = make_translator(code)
    # The outer else runs without a flag
    assert "println('outer done')" in result, f"Expected outer else in:\n{result}"
    # The outer loop has no py_loop_completed flag (inner break doesn't affect it)
    assert "py_loop_completed" not in result, (
        f"Inner break must NOT create outer loop flag:\n{result}"
    )


def test_while_else_break_in_nested_if_uses_flag():
    """while/else with break inside nested if uses the flag mechanism."""
    code = (
        "i = 0\n"
        "while i < 10:\n"
        "    if i == 3:\n"
        "        break\n"
        "    i += 1\n"
        "else:\n"
        "    print('while done')"
    )
    result = make_translator(code)
    assert "py_loop_completed" in result, f"Expected flag for while/else:\n{result}"
    assert "= false" in result, f"Expected flag=false before break:\n{result}"
    assert "if py_loop_completed" in result, f"Expected flag guard:\n{result}"
    assert "println('while done')" in result, f"Expected while else body:\n{result}"


def test_while_else_no_break_runs_unconditionally():
    """while/else with no break: else runs without flag."""
    code = (
        "i = 0\n"
        "while i < 3:\n"
        "    i += 1\n"
        "else:\n"
        "    print('done')"
    )
    result = make_translator(code)
    assert "println('done')" in result, f"Expected else body in:\n{result}"
    assert "py_loop_completed" not in result, f"No flag expected when no break:\n{result}"


# ---------------------------------------------------------------------------
# for/else with range (step 3 args) — verify the range-path also works
# ---------------------------------------------------------------------------

def test_for_else_range_step_with_break():
    """for i in range(0, 10, 2): break — range with step should use flag."""
    code = (
        "for i in range(0, 10, 2):\n"
        "    if i == 4:\n"
        "        break\n"
        "else:\n"
        "    print('range step done')"
    )
    result = make_translator(code)
    assert "py_loop_completed" in result, f"Expected flag for range-step for/else:\n{result}"
    assert "if py_loop_completed" in result, f"Expected flag guard:\n{result}"
    assert "println('range step done')" in result, f"Expected else body:\n{result}"
