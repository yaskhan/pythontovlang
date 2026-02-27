from typing import List
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.parser import PyASTParser

def transpile(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

def test_pow_assign_simple():
    source = """
x = 2
x **= 3
"""
    v_code = transpile(source)
    assert "x = math.pow(x, 3)" in v_code
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
    assert "x = x / 2" in v_code

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
    assert ".x =" in v_code and " / 2" in v_code

def test_pow_assign_nested_subscript():
    source = """
def f(): return 0
def g(): return 1
arr = [[1, 2], [3, 4]]
arr[f()][g()] **= 2
"""
    v_code = transpile(source)
    # Outer target: arr[f()][g()]
    # Base: arr[f()] -> captured to tmp1 := arr[f()]
    # Index: g() -> captured to tmp2 := g()
    # Result: tmp1[tmp2] = ...

    print(v_code)
    assert "_aug_tmp_" in v_code
    # We check that f() and g() appear in assignments
    assert ":= f()" in v_code or "arr[f()]" in v_code
    # Actually if arr[f()] is visited, it emits arr[f()].
    # If captured, it puts it in assignment.
    # Because _capture_value calls visit(arr[f()]), which emits string "arr[f()]"
    # Then creates "tmp := arr[f()]".
    assert ":= arr[f()]" in v_code
    assert ":= g()" in v_code
