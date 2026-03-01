import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_functools_reduce():
    source = """
import functools
import operator
l = [1, 2, 3]
res = functools.reduce(operator.add, l)
"""
    v_code = translate(source)
    assert "py_reduce" in v_code
    assert "py_op_add" in v_code

def test_functools_reduce_lambda():
    source = """
import functools
l = [1, 2, 3]
res = functools.reduce(lambda x, y: x * y, l)
"""
    v_code = translate(source)
    assert "py_reduce" in v_code
    assert "fn (x int, y int) int" in v_code

def test_lru_cache_comment():
    source = """
import functools
@functools.lru_cache(maxsize=None)
def fib(n):
    return n
"""
    v_code = translate(source)
    # Just checking existing behavior
    assert "fib_cache" in v_code
