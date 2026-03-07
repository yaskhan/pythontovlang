import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_open_read():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
f = open('test.txt')
content = f.read()
f.close()
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert 'import os' in result
    assert "f := os.open('test.txt')" in result.replace('"', "'")
    assert "content := py_file_read_all(mut f)" in result

def test_with_open():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
with open('data.json') as f:
    data = f.read()
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert 'import os' in result
    assert "f := os.open('data.json')" in result.replace('"', "'")
    assert "defer { f.close() }" in result
    assert "data := py_file_read_all(mut f)" in result
