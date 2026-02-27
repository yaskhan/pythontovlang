import ast
from typing import List, cast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.parser import PyASTParser

def transpile(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    # Ensure tree is treated as ast.Module for MyPy
    return translator.visit_Module(cast(ast.Module, tree))

def test_pow_assign_simple():
    source = """
x = 2
x **= 3
"""
    v_code = transpile(source)
    # x is int, so we expect cast
    assert "x = int(math.pow(x, 3))" in v_code
    assert "import math" in v_code

def test_pow_assign_complex_subscript():
    source = """
def f(): return 0
arr = [1, 2, 3]
arr[f()] **= 2
"""
    v_code = transpile(source)
    # Check that f() is assigned to a temp variable
    # We expect something like:
    # _aug_tmp_1 := f()
    # arr[_aug_tmp_1] = math.pow(arr[_aug_tmp_1], 2)

    print(v_code)
    assert "_aug_tmp_" in v_code
    assert ":= f()" in v_code
    assert "math.pow" in v_code

def test_floordiv_assign_simple():
    source = """
x = 10
x //= 2
"""
    v_code = transpile(source)
    # Default to integer division for unknown type
    assert "x = int(math.floor(f64(x) / f64(2)))" in v_code

def test_floordiv_assign_complex_attr():
    source = """
class A:
    x = 10
def get_obj():
    return A()

get_obj().x //= 2
"""
    v_code = transpile(source)
    # Should capture get_obj()
    assert "_aug_tmp_" in v_code
    assert ":= get_obj()" in v_code
    # Assuming integer division or floor depending on inference, but here likely int
    assert ".x = int(math.floor(f64(" in v_code

def test_pow_assign_nested_subscript():
    source = """
def f(): return 0
def g(): return 1
arr = [[1, 2], [3, 4]]
arr[f()][g()] **= 2
"""
    v_code = transpile(source)

    # Check that f() and g() are captured in assignments
    assert "_aug_tmp_" in v_code
    # Should contain assignments for f() and g() calls
    assert ":= f()" in v_code
    assert ":= g()" in v_code
    # Target should be arr[_aug_tmp_1][_aug_tmp_2] approximately
    # Since _capture_target recurses, arr[f()] is base.
    # Base _capture_target(arr[f()]) -> base is arr (Name)
    #   Subscript arr[f()]. Base=arr. Index=f().
    #   f() -> captured: tmp_f := f()
    #   returns arr[tmp_f]
    # Then outer Subscript: base=arr[tmp_f], index=g()
    #   g() -> captured: tmp_g := g()
    #   returns arr[tmp_f][tmp_g]
    # So NO `tmp := arr[f()]`. The path is preserved.

    assert "arr[" in v_code and "][" in v_code

def test_pow_assign_nested_attribute():
    source = """
class A:
    x = 10
def f(): return A()

# f() returns object (Call). Base is Call.
# _capture_target(f().x) -> base is f() (Call)
# Since base is Call (not L-value container like Name/Attr/Subscript), it uses _capture_value.
# tmp := f()
# tmp.x = ...
f().x **= 2
"""
    v_code = transpile(source)
    assert ":= f()" in v_code
    assert ".x =" in v_code

def test_pow_assign_struct_field():
    source = """
class Pt:
    x = 0
arr = [Pt()]
# arr[0].x **= 2
# _capture_target(arr[0].x)
# Base arr[0] (Subscript). Recurse.
# Base arr (Name). Recurse -> "arr".
# Index 0 (Constant). Recurse -> "0".
# Returns arr[0].x
# No temp vars needed for static indices.
arr[0].x **= 2
"""
    v_code = transpile(source)
    # Should NOT contain temp vars for arr or 0
    # But wait, unique_id_counter increases globally.
    # We check if structure is preserved: arr[0].x = ...
    assert "arr[0].x =" in v_code
    # And check for int cast (x is int)
    assert "int(math.pow" in v_code
