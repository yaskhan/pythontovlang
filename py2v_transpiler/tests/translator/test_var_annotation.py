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

def test_var_annotation_int():
    source = """
x: int
"""
    v_code = translate(source)
    assert "mut x := 0" in v_code or "x :=" in v_code

def test_var_annotation_string():
    source = """
name: str
"""
    v_code = translate(source)
    assert "name :=" in v_code
    assert "''" in v_code or "string" in v_code

def test_var_annotation_float():
    source = """
value: float
"""
    v_code = translate(source)
    assert "value :=" in v_code
    assert "0.0" in v_code or "f64" in v_code

def test_var_annotation_bool():
    source = """
flag: bool
"""
    v_code = translate(source)
    assert "flag :=" in v_code
    assert "false" in v_code

def test_var_annotation_with_assignment():
    source = """
x: int = 42
"""
    v_code = translate(source)
    assert "x := 42" in v_code

def test_var_annotation_list():
    source = """
from typing import List
items: List[int]
"""
    v_code = translate(source)
    assert "items :=" in v_code
    assert "[]" in v_code or "int" in v_code

def test_var_annotation_dict():
    source = """
from typing import Dict
data: Dict[str, int]
"""
    v_code = translate(source)
    assert "data :=" in v_code
    assert "map" in v_code or "{}" in v_code
