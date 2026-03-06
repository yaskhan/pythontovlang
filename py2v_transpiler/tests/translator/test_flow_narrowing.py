import ast
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def test_isinstance_narrowing_generation():
    code = """
def f(x):
    if isinstance(x, int):
        print(x + 1)
    else:
        print(x + "!")
"""
    tree = ast.parse(code)
    ti = TypeInference()
    ti.type_map["x"] = "int | string"

    tr = VNodeVisitor(ti)
    full_output = tr.visit_Module(tree)

    assert "if x is int {" in full_output
    assert "// x narrowed to int" in full_output
    assert "} else {" in full_output

def test_none_narrowing_generation():
    code = """
def f(x):
    if x is not None:
        print(x + 1)
"""
    tree = ast.parse(code)
    ti = TypeInference()
    ti.type_map["x"] = "?int"

    tr = VNodeVisitor(ti)
    full_output = tr.visit_Module(tree)

    assert "if x != none {" in full_output
    assert "// x narrowed to int" in full_output

def test_none_narrowing_inverse_generation():
    code = """
def f(x):
    if x is None:
        pass
    else:
        print(x + 1)
"""
    tree = ast.parse(code)
    ti = TypeInference()
    ti.type_map["x"] = "?int"

    tr = VNodeVisitor(ti)
    full_output = tr.visit_Module(tree)

    assert "if x == none {" in full_output
    assert "} else {" in full_output
    assert "// x narrowed to int" in full_output
