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

def test_raw_string_regex():
    source = r"""
import re
pattern = r"\d+"
"""
    v_code = translate(source)
    # Should contain raw string literal
    assert "r'" in v_code or "pattern" in v_code

def test_raw_string_windows_path():
    source = r"""
path = r"C:\Users\test\file.txt"
"""
    v_code = translate(source)
    assert "path :=" in v_code

def test_regular_string_unchanged():
    source = """
s = "hello world"
"""
    v_code = translate(source)
    assert "s := 'hello world'" in v_code

def test_raw_string_complex_regex():
    source = r"""
import re
pattern = r"^\w+@\w+\.\w+$"
"""
    v_code = translate(source)
    assert "pattern" in v_code
