import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast
import re

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_destructuring_head_star():
    code = """
a, *b = l
"""
    v_code = transpile(code)
    assert "py_destruct_" in v_code
    assert re.search(r":= py_destruct_\d+", v_code) # temp assignment
    assert re.search(r"\[0\]", v_code)
    assert re.search(r"\[1\.\.\]", v_code)

def test_destructuring_star_tail():
    code = """
*a, b = l
"""
    v_code = transpile(code)
    assert "len-1]" in v_code
    assert "len-1" in v_code

def test_destructuring_middle_star():
    code = """
a, *b, c = l
"""
    v_code = transpile(code)
    assert "[0]" in v_code
    assert "len-1]" in v_code
    assert re.search(r"1\.\.py_destruct_", v_code)

def test_simple_unpacking_optimized():
    code = """
a, b = 1, 2
"""
    v_code = transpile(code)
    # Expect optimization: a, b := 1, 2
    assert "a, b := 1, 2" in v_code
    assert "_destruct_" not in v_code

def test_simple_unpacking_variable():
    code = """
a, b = l
"""
    v_code = transpile(code)
    assert "py_destruct_" in v_code
    # Expect a := py_destruct_X[0]
    assert re.search(r"a := py_destruct_\d+\[0\]", v_code)
    assert re.search(r"b := py_destruct_\d+\[1\]", v_code)
