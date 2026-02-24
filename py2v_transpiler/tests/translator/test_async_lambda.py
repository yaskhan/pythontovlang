import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_lambda():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "f = lambda x: x + 1"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Lambda translates to anonymous function
    assert "f := fn (x int) int { return x + 1 }" in result

def test_translator_async_def():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
async def foo(a: int) -> int:
    return a
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Async function translates to normal function (V uses spawn/go)
    assert "fn foo(a int) int {" in result
    assert "return a" in result

def test_translator_await():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = await foo()"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Await translates to commented call
    assert "x := /* await */ foo()" in result
