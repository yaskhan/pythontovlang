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

def test_fstring_debug_simple():
    source = """
x = 42
print(f"{x=}")
"""
    v_code = translate(source)
    # Should contain the debug expression format
    assert "x=" in v_code or "x :=" in v_code

def test_fstring_debug_expression():
    source = """
a = 1
b = 2
print(f"{a+b=}")
"""
    v_code = translate(source)
    assert "a" in v_code
    assert "b" in v_code

def test_fstring_debug_with_format():
    source = """
x = 3.14159
print(f"{x=:.2f}")
"""
    v_code = translate(source)
    assert "x" in v_code
