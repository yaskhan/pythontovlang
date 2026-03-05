import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_init_inference_basic():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
class Data:
    def __init__(self):
        self.value = 0
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct Data {" in result
    assert "value int" in result

def test_init_inference_annotated():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
class Data:
    def __init__(self):
        self.value: int | str = 0
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct Data {" in result
    assert "value SumType_IntString" in result
    assert "type SumType_IntString = int | string" in result

def test_init_inference_multiple():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
class Data:
    def __init__(self, x: int, y: str):
        self.x = x
        self.y = y
        self.z = 0.5
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct Data {" in result
    assert "x int" in result
    assert "y string" in result
    assert "z f64" in result

def test_init_inference_nested():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
class Data:
    def __init__(self, cond: bool):
        if cond:
            self.a = 1
        else:
            self.b = "hello"
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct Data {" in result
    assert "a int" in result
    assert "b string" in result

def test_init_inference_mixed():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
class Data:
    base: int
    def __init__(self):
        self.value = 0
        self.base = 1
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct Data {" in result
    assert "base int" in result
    assert "value int" in result
    # Ensure no duplicates in struct definition string
    assert result.count("base int") == 1
    assert result.count("value int") == 1
