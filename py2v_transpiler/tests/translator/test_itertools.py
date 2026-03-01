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

def test_itertools_chain():
    source = """
import itertools
l1 = [1, 2]
l2 = [3, 4]
res = itertools.chain(l1, l2)
"""
    v_code = translate(source)
    # V: res := py_chain(l1, l2)
    assert "res := py_chain(l1, l2)" in v_code

def test_itertools_repeat():
    source = """
import itertools
res = itertools.repeat(1, 5)
"""
    v_code = translate(source)
    # V: res := []int{len: 5, init: 1} or py_repeat(1, 5)
    assert "res := py_repeat(1, 5)" in v_code

def test_itertools_count():
    source = """
import itertools
for i in itertools.count(1):
    if i > 10:
        break
"""
    v_code = translate(source)
    # V: for i in py_count(1, 1) { ... }
    assert "for i in py_count(1, 1)" in v_code

def test_itertools_count_step():
    source = """
import itertools
c = itertools.count(1, 2)
"""
    v_code = translate(source)
    assert "c := py_count(1, 2)" in v_code

def test_itertools_cycle():
    source = """
import itertools
l = [1, 2, 3]
for x in itertools.cycle(l):
    break
"""
    v_code = translate(source)
    # V: for x in py_cycle(l) { ... }
    assert "for x in py_cycle(l)" in v_code
