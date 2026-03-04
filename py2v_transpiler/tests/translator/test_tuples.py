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

    assert "mut t := []int{cap: 2}" in result
    assert "t << 1" in result
    assert "t << 2" in result

def test_translator_tuple_mixed():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    # Mixed type tuples map to arrays in V, which requires sum types or Any.
    # Our current simplistic translator will just emit [1, 'a'], which might be invalid V without casting.
    # But for now we just verify the translation logic.
    code = "t = (1, 'a')"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "mut t := []Any{cap: 2}" in result
    assert "t << 1" in result
    assert "t << 'a'" in result
