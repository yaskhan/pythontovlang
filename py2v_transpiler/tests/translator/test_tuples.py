import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_tuple_literal():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "t = (1, 2)"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "t := [1, 2]" in result

def test_translator_tuple_mixed():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    # Mixed type tuples map to specialized structs in V for type safety.
    code = "t = (1, 'a')"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct PyTuple_int_string" in result
    assert "t := PyTuple_int_string{f0: 1, f1: 'a'}" in result
