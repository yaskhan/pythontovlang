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

def test_nested_class_basic():
    source = """
class Outer:
    def __init__(self):
        self.x = 1
    
    class Inner:
        def __init__(self):
            self.y = 2
"""
    v_code = translate(source)
    assert "struct Outer {" in v_code
    assert "struct Outer_Inner {" in v_code

def test_nested_class_two_levels():
    source = """
class A:
    class B:
        class C:
            def __init__(self):
                self.val = 0
"""
    v_code = translate(source)
    assert "struct A {" in v_code
    assert "struct A_B {" in v_code
    assert "struct A_B_C {" in v_code

def test_nested_class_with_methods():
    source = """
class Container:
    def method(self):
        pass
    
    class Item:
        def process(self):
            pass
"""
    v_code = translate(source)
    assert "struct Container {" in v_code
    assert "struct Container_Item {" in v_code
    assert "fn (self Container) method()" in v_code
    assert "fn (self Container_Item) process()" in v_code

def test_nested_class_with_fields():
    source = """
class Parent:
    x: int
    
    class Child:
        y: str
"""
    v_code = translate(source)
    assert "struct Parent {" in v_code
    assert "struct Parent_Child {" in v_code
    assert "x int" in v_code
    assert "y string" in v_code
