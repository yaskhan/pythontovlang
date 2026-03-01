import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    tree = ast.parse(code)
    # Pre-analyze types
    analyzer.visit(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

def test_dict_comp_simple():
    code = "d = {x: x*2 for x in range(5)}"
    v_code = transpile(code)
    assert "map[int]int" in v_code
    assert "d[x] = x * 2" in v_code

def test_dict_comp_string_key():
    code = "d = {str(x): x for x in range(5)}"
    v_code = transpile(code)
    assert "map[string]int" in v_code
    assert "d[str(x)] = x" in v_code

def test_dict_comp_string_val():
    code = "d = {x: str(x) for x in range(5)}"
    v_code = transpile(code)
    assert "map[int]string" in v_code
    assert "d[x] = str(x)" in v_code

def test_dict_comp_zip():
    code = "d = {k: v for k, v in zip(['a', 'b'], [1, 2])}"
    v_code = transpile(code)
    assert "map[string]int" in v_code
    assert "d[k] = v" in v_code
