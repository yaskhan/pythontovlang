import pytest
import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_basic_lambda_capture():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def foo():
    n = 10
    add_n = lambda x: x + n
    print(add_n(5))
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # In V: fn [n] (x int) int { return x + n }
    assert "fn [n] (x int) int { return x + n }" in result

def test_nested_lambda_capture():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "multiplier = lambda n: lambda x: x * n"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # multiplier := fn (n int) int { return fn [n] (x int) int { return x * n } }
    assert "fn [n] (x int) int { return x * n }" in result

def test_lambda_variadic_args_order():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "f = lambda *args, **kwargs: args[0]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Variadic (args) must be last in V signature
    # Type inference might return 'Any' for args[0]
    assert "fn (kwargs map[string]int, args ...int)" in result
    assert "//##LLM@@ Lambda has both *args and **kwargs" in result

def test_lambda_kwonly_args():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "f = lambda x, *, y: x + y"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "fn (x int, y int) int { return x + y }" in result

def test_lambda_no_capture_top_level():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "n = 10\nf = lambda x: x + n"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Top-level variables are module-level, V closures don't capture them in brackets.
    assert "fn (x int) int { return x + n }" in result

def test_deeply_nested_lambda_capture():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "f = lambda a: lambda b: lambda c: a + b + c"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # fn (a int) int { return fn [a] (b int) int { return fn [a, b] (c int) int { return a + b + c } } }
    assert "fn [a] (b int) int { return fn [a, b] (c int) int { return a + b + c } }" in result
