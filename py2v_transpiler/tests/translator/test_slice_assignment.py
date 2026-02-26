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

def test_slice_assignment_basic():
    source = """
l = [1, 2, 3, 4, 5]
l[1:3] = [10, 20]
"""
    v_code = translate(source)
    assert "py_slice_assign" in v_code
    assert "l" in v_code

def test_slice_assignment_from_start():
    source = """
l = [1, 2, 3]
l[:2] = [0, 0]
"""
    v_code = translate(source)
    assert "py_slice_assign" in v_code

def test_slice_assignment_to_end():
    source = """
l = [1, 2, 3]
l[1:] = [20, 30]
"""
    v_code = translate(source)
    assert "py_slice_assign" in v_code

def test_slice_assignment_different_length():
    source = """
l = [1, 2, 3]
l[0:2] = [10, 20, 30, 40]
"""
    v_code = translate(source)
    assert "py_slice_assign" in v_code
