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
    return v_code

def test_nested_or_in_sequence():
    source = """
match x:
    case [0 | 1, 2]:
        print("match")
"""
    v_code = translate(source)
    # Check for OR pattern logic inside sequence
    assert "== 0" in v_code
    assert "== 1" in v_code
    assert "== 2" in v_code
    # Verify no double else bug
    assert "else if else" not in v_code

def test_nested_or_in_mapping():
    source = """
match x:
    case {"a": 0 | 1}:
        print("match")
"""
    v_code = translate(source)
    assert "== 0" in v_code
    assert "== 1" in v_code
    assert "else if else" not in v_code

def test_nested_or_in_class_positional():
    source = """
match p:
    case Point(0 | 1, y):
        print(y)
"""
    v_code = translate(source)
    # Point(0 | 1, y) uses positional patterns.
    # Current implementation might fail to map them to attributes.
    assert "Point" in v_code
    assert "== 0" in v_code
    assert "== 1" in v_code
    assert "y :=" in v_code

def test_nested_or_with_bindings():
    source = """
match x:
    case [(int() as y) | (str() as y)]:
        print(y)
"""
    v_code = translate(source)
    print(v_code)
    # This should generate conditional binding for y
    assert "y := if" in v_code
    assert "as Int" in v_code
    assert "as String" in v_code

def test_deeply_nested_or():
    source = """
match x:
    case [[0 | 1] | [2 | 3]]:
        print("match")
"""
    v_code = translate(source)
    assert "== 0" in v_code
    assert "== 1" in v_code
    assert "== 2" in v_code
    assert "== 3" in v_code

if __name__ == "__main__":
    import pytest
    import sys
    pytest.main([__file__])
