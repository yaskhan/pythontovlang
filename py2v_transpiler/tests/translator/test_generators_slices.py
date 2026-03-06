import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_generator_yield():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def gen():
    yield 1
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Yield translates to channel push
    assert "py_yield(ch_out, ch_in, 1)" in result
    assert "ch_out.close()" in result
    assert "fn gen(ch_out chan int, ch_in chan PyGeneratorInput) {" in result

def test_translator_list_indexing():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = l[0]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := l[0]" in result

def test_translator_list_slicing():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = l[1:3]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := l[1..3]" in result

def test_translator_list_slicing_omitted():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = l[:3]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := l[..3]" in result

    code = "y = l[1:]"
    tree = parser.parse(code)
    result = translator.visit_Module(tree)
    assert "y := l[1..]" in result
