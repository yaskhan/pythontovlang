import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_class_variables_definition():
    source = """
class MyClass:
    class_var = 10
    _private_var: str = "secret"
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    assert "pub struct MyClassMeta {" in code
    assert "class_var int = 10" in code
    assert "private_var string = 'secret'" in code
    assert "pub const my_class_meta = &MyClassMeta{}" in code

def test_class_variables_access():
    source = """
class MyClass:
    count = 0

MyClass.count += 1
obj = MyClass()
print(obj.count)
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    assert "my_class_meta.count += 1" in code
    assert "println('${my_class_meta.count}')" in code

def test_inherited_class_variable_access():
    source = """
class Vehicle:
    wheels = 4

class Car(Vehicle):
    pass

print(Car.wheels)
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Should find wheels in Vehicle and use vehicle_meta singleton
    assert "println('${vehicle_meta.wheels}')" in code
