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

def test_sorted_builtin():
    source = """
a = [3, 1, 2]
b = sorted(a)
"""
    v_code = translate(source)
    assert "b := py_sorted(a)" in v_code
    assert "fn py_sorted[T](a []T) []T" in v_code

def test_reversed_builtin():
    source = """
a = [1, 2, 3]
b = reversed(a)
"""
    v_code = translate(source)
    assert "b := py_reversed(a)" in v_code
    assert "fn py_reversed[T](a []T) []T" in v_code

def test_sorted_reversed_loop():
    source = """
a = [1, 2]
for x in reversed(sorted(a)):
    pass
"""
    v_code = translate(source)
    assert "for x in py_reversed(py_sorted(a)) {" in v_code
    assert "fn py_sorted" in v_code
    assert "fn py_reversed" in v_code
