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
    return translator.visit_Module(tree)

def test_any_basic():
    source = """
a = [True, False]
b = any(a)
"""
    v_code = translate(source)
    assert "b := a.any(it)" in v_code

def test_all_basic():
    source = """
a = [1, 2]
b = all(a)
"""
    v_code = translate(source)
    assert "b := a.all(it)" in v_code

def test_any_generator():
    source = """
nums = [1, 2, 3]
b = any(x > 0 for x in nums)
"""
    v_code = translate(source)
    assert "b := nums.any(it > 0)" in v_code

def test_all_generator():
    source = """
nums = [1, 2, 3]
b = all(y < 10 for y in nums)
"""
    v_code = translate(source)
    assert "b := nums.all(it < 10)" in v_code

def test_any_generator_renamed():
    # Ensure nested renaming works or at least basic usage
    source = """
nums = [1, 2]
b = any(val == 1 for val in nums)
"""
    v_code = translate(source)
    assert "b := nums.any(it == 1)" in v_code
