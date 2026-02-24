import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_try_except():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
try:
    x = 1 / 0
except ZeroDivisionError:
    print("oops")
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "// try {" in result
    assert "x := 1 / 0" in result
    assert "// } except {" in result
    assert "// Handler:" in result

def test_translator_with():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
with open("file.txt") as f:
    print(f.read())
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert 'f := open("file.txt")' in result.replace("'", '"')
    assert "defer { f.close() }" in result
    assert "print(f.read())" in result
