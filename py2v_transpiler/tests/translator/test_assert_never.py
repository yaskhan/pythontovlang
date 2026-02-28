import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_assert_never():
    code = """
import typing

def func(val: int):
    typing.assert_never(val)
"""
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.visit(tree)
    visitor = VNodeVisitor(analyzer)
    result = visitor.visit_Module(tree)

    assert "$compile_error('assert_never reached: variable is typed as int instead of void/Never')" in result

def test_assert_never_from_import():
    code = """
from typing import assert_never

def func(val: int):
    assert_never(val)
"""
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.visit(tree)
    visitor = VNodeVisitor(analyzer)
    result = visitor.visit_Module(tree)

    assert "$compile_error('assert_never reached: variable is typed as int instead of void/Never')" in result

def test_assert_never_void_arg():
    code = """
import typing
def func(val: typing.NoReturn):
    typing.assert_never(val)
"""
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.visit(tree)
    visitor = VNodeVisitor(analyzer)
    result = visitor.visit_Module(tree)

    assert "panic('assert_never reached')" in result

def test_assert_never_no_args():
    code = """
from typing import assert_never

def func():
    assert_never()
"""
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.visit(tree)
    visitor = VNodeVisitor(analyzer)
    result = visitor.visit_Module(tree)

    assert "panic('assert_never reached')" in result
