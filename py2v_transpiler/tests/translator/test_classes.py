import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_class_def():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
class Point:
    x: int
    y: int

    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y

    def move(self, dx: int, dy: int):
        self.x = self.x + dx
        self.y = self.y + dy
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct Point {" in result
    assert "x int" in result
    assert "y int" in result

    # Check factory function for __init__
    assert "fn new_point(x int, y int) Point {" in result
    assert "self.x = x" in result

    # Check method
    assert "fn (self Point) move(dx int, dy int) {" in result
    assert "self.x = self.x + dx" in result

def test_translator_class_usage():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
p = Point(1, 2)
p.move(3, 4)
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "p := Point(1, 2)" in result
    assert "p.move(3, 4)" in result
