import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_map_builtin():
    source = """
a = [1, 2, 3]
b = map(str, a)
"""
    v_code = translate(source)
    assert "b := a.map(str(it))" in v_code

def test_filter_builtin():
    source = """
a = [1, 2, 3]
b = filter(is_valid, a)
"""
    v_code = translate(source)
    assert "b := a.filter(is_valid(it))" in v_code

def test_filter_none():
    source = """
a = [True, False]
b = filter(None, a)
"""
    v_code = translate(source)
    assert "b := a.filter(it)" in v_code

def test_filter_lambda():
    source = """
nums = [1, 2, 3]
evens = filter(lambda x: x % 2 == 0, nums)
"""
    v_code = translate(source)
    # Should NOT have (it) suffix
    assert "evens := nums.filter(fn (x int) bool { return x % 2 == 0 })" in v_code

def test_map_lambda():
    source = """
nums = [1, 2, 3]
squares = map(lambda x: x * x, nums)
"""
    v_code = translate(source)
    # Should NOT have (it) suffix
    assert "squares := nums.map(fn (x int) int { return x * x })" in v_code
