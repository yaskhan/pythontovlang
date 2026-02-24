import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_function_with_types():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def add(a: int, b: int) -> int:
    return a + b
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "fn add(a int, b int) int {" in result
    assert "return a + b" in result
    assert "}" in result

def test_translator_function_call():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "print('hello')"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "println('hello')" in result

def test_translator_return_none():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def foo():
    return
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "return" in result

def test_full_module_generation():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def add(a: int, b: int) -> int:
    return a + b

x = 1
y = 2
z = add(x, y)
print(z)
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "module main" in result
    assert "fn add(a int, b int) int {" in result
    assert "fn main() {" in result
    assert "x := 1" in result
    assert "z := add(x, y)" in result
