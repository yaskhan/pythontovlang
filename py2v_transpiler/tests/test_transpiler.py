import os
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_parser_simple():
    parser = PyASTParser()
    code = "x = 1"
    tree = parser.parse(code)
    assert tree is not None

def test_translator_assignment():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = 1"
    tree = parser.parse(code)
    result = translator.visit_Module(tree)

    assert "x := 1" in result

def test_translator_function():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def add(a, b):
    return a + b
"""
    tree = parser.parse(code)
    result = translator.visit_Module(tree)

    assert "fn add(a, b) {" in result
    assert "}" in result
