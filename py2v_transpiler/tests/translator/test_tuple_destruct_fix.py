import pytest
import ast
from typing import cast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.parser import PyASTParser

def transpile(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(cast(ast.Module, tree))

def test_tuple_struct_assignment_destructuring():
    content = """
from typing import Tuple
def test(coords: Tuple[int, str]):
    x, y = coords
"""
    v_code = transpile(content)
    assert "x := py_destruct_0.it_0" in v_code
    assert "y := py_destruct_0.it_1" in v_code
    assert "py_destruct_0[0]" not in v_code

def test_tuple_struct_loop_destructuring():
    content = """
from typing import List, Tuple
def test(items: List[Tuple[int, str]]):
    for x, y in items:
        pass
"""
    v_code = transpile(content)
    # The variable name is dynamic (contains id), so we check for the structure
    assert ".it_0" in v_code
    assert ".it_1" in v_code
    assert "[0]" not in v_code

def test_tuple_struct_comp_destructuring():
    content = """
from typing import List, Tuple
def test(items: List[Tuple[int, str]]):
    res = [x for x, y in items]
"""
    v_code = transpile(content)
    assert ".it_0" in v_code
    assert ".it_1" in v_code
    assert "for [x, y] in" not in v_code

def test_plain_list_destructuring_remains_unchanged():
    content = """
def test(items: list[int]):
    x, y = items
"""
    v_code = transpile(content)
    assert "[0]" in v_code
    assert ".it_0" not in v_code
