import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def transpile_with_sigs(code: str, sigs: dict) -> str:
    tree = ast.parse(code)
    inference = TypeInference()
    inference.call_signatures = sigs
    visitor = VNodeVisitor(inference)
    visitor.visit(tree)
    return visitor.emitter.emit()

def test_generic_instantiation_monomorphization():
    code = """
from typing import TypeVar, Generic
T = TypeVar("T")
class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x

b = Box(1)
"""
    sigs = {
        "8:4": {
            "is_class": True,
            "has_init": True,
            "return": "Box[builtins.int]"
        }
    }

    out = transpile_with_sigs(code, sigs)
    assert "new_Box[int](1)" in out

def test_multiple_generics_monomorphization():
    code = """
from typing import TypeVar, Generic
T = TypeVar("T")
U = TypeVar("U")
class Pair(Generic[T, U]):
    def __init__(self, first: T, second: U):
        self.first = first
        self.second = second

p = Pair("hello", 42)
"""
    sigs = {
        "10:4": {
            "is_class": True,
            "has_init": True,
            "return": "Pair[builtins.str, builtins.int]"
        }
    }

    out = transpile_with_sigs(code, sigs)
    assert "new_Pair[string, int]('hello', 42)" in out

def test_nested_generics_monomorphization():
    code = """
from typing import TypeVar, Generic
T = TypeVar("T")
class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x

l = Box([1, 2, 3])
"""
    sigs = {
        "8:4": {
            "is_class": True,
            "has_init": True,
            "return": "Box[builtins.list[builtins.int]]"
        }
    }

    out = transpile_with_sigs(code, sigs)
    assert "new_Box[[]int]([1, 2, 3])" in out
