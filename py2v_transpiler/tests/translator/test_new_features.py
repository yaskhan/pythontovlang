import ast
from typing import cast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def _transpile(code: str) -> str:
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = parser.parse(code)
    analyzer.analyze(tree)
    module_tree = cast(ast.Module, tree)
    return translator.visit_Module(module_tree)

def test_del_multiple():
    code = "del a, b"
    v_code = _transpile(code)
    assert "//##LLM@@ 'del a' statement ignored" in v_code
    assert "//##LLM@@ 'del b' statement ignored" in v_code

def test_bitwise_ops():
    code = "c = a & b | d ^ e"
    v_code = _transpile(code)
    assert "&" in v_code
    assert "|" in v_code
    assert "^" in v_code

def test_if_exp():
    code = "x = 1 if y else 2"
    v_code = _transpile(code)
    # y is inferred as int by fallback, so it's y != 0
    assert "if y != 0 { 1 } else { 2 }" in v_code

def test_dataclass():
    code = """
from dataclasses import dataclass

@dataclass
class Point:
    x: int
    y: int

p = Point(1, 2)
"""
    v_code = _transpile(code)
    assert "struct Point {" in v_code
    assert "x int" in v_code
    assert "y int" in v_code
    assert "Point{x: 1, y: 2}" in v_code

def test_dataclass_with_args():
    code = """
from dataclasses import dataclass

@dataclass(frozen=True)
class FrozenPoint:
    x: int

p = FrozenPoint(1)
"""
    v_code = _transpile(code)
    assert "struct FrozenPoint {" in v_code
    assert "x int" in v_code
    assert "FrozenPoint{x: 1}" in v_code
