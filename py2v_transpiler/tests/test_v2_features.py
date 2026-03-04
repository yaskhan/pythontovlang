import ast
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile(code):
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_generics():
    code = """
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
    v_code = transpile(code)
    assert "type U = int | string" in v_code
    assert "struct Base[T] {" in v_code
    assert "struct Child {" in v_code
    assert "base Base[int]" in v_code
    assert "fn new_Base[T](val T) Base[T]" in v_code
    assert "fn (self Child) method(x U) U" in v_code

def test_comparisons():
    code = """
class Parent:
    def greet(self):
        pass

class Child(Parent):
    def greet(self):
        super().greet()

def check(x):
    if x is None:
        pass
    if x is not None:
        pass
    t = type(x)
    cls = x.__class__
    if isinstance(x, int):
        pass
"""
    v_code = transpile(code)
    assert "struct Child {" in v_code
    assert "Parent" in v_code # Embedding
    assert "self.Parent.greet()" in v_code
    assert "if x == none" in v_code
    assert "if x != none" in v_code
    assert "typeof(x).name" in v_code
    assert "typeof(x)" in v_code
    assert "if x is int" in v_code

def test_fstrings():
    code = """
x = 42
s = f"Val: {x:05}"
escapes = f"Line\\nBreak\\tTab 'Quote'"
"""
    v_code = transpile(code)
    assert "s := 'Val: ${x:05}'" in v_code
    # check escaping
    assert r"Line\nBreak\tTab \'Quote\'" in v_code
