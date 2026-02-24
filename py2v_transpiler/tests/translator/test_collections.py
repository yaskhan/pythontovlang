import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_list_comp():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = [i for i in range(10)]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "mut x := []int{}" in result
    assert "for i in 0..10 {" in result
    assert "x << i" in result

def test_translator_list_comp_filter():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = [i for i in range(10) if i > 5]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "mut x := []int{}" in result
    assert "for i in 0..10 {" in result
    assert "if i > 5 {" in result
    assert "x << i" in result

def test_translator_dict_literal():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "d = {'a': 1, 'b': 2}"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "d := map[string]int{'a': 1, 'b': 2}" in result

def test_translator_dict_empty():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "d = {}"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "d := map[string]int{}" in result
