from py2v_transpiler.tests.test_v2_features import transpile
code_generics = """
from typing import Generic, TypeVar, Union

T = TypeVar("T")
U = TypeVar("U", int, str)

class Base(Generic[T]):
    def __init__(self, val: T):
        self.val = val

class Child(Base[int]):
    def method(self, x: U) -> U:
        return x
"""
v_code = transpile(code_generics)
print("TEST GENERICS VAL MUTABLE?:", "mut val" in v_code)

code_none = """
def test_none_ternary():
    def get_value(x=None):
        return "No value" if x is None else f"Value: {x}"

    print(get_value())
    print(get_value(42))
"""
v_code_none = transpile(code_none)
print("TEST NONE X MUTABLE?:", "mut x" in v_code_none)
