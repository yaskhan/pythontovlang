import pytest
import ast
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def test_assert_type_pass():
    code = """
from typing import assert_type

def test_fn():
    x = 10
    assert_type(x, int)
    """
    tree = ast.parse(code)

    analyzer = TypeInference()
    analyzer.visit(tree)

    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)

    assert "// assert_type(x, int) passed statically" in v_code
    assert "$compile_error" not in v_code

def test_assert_type_fail():
    code = """
from typing import assert_type

def test_fn():
    x = 10
    assert_type(x, float)
    """
    tree = ast.parse(code)

    analyzer = TypeInference()
    analyzer.visit(tree)

    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)

    assert "$compile_error('assert_type failed: expected f64 but got int')" in v_code
