import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_class_variables_definition():
    source = """
class Vehicle:
    wheels = 4
    brand: str = "Generic"
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Should be in struct
    assert "wheels int = 4" in code
    assert "brand string = 'Generic'" in code

    # Should be constants
    assert "pub const Vehicle_wheels = 4" in code
    assert "pub const Vehicle_brand = 'Generic'" in code

def test_class_variables_access():
    source = """
class Vehicle:
    wheels = 4

v = Vehicle()
print(v.wheels)
print(Vehicle.wheels)
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Instance access (via struct field)
    assert "println('${v.wheels}')" in code
    # Class access (via constant)
    assert "println('${Vehicle_wheels}')" in code

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

    # Should find wheels in Vehicle and use Vehicle_wheels constant
    assert "println('${Vehicle_wheels}')" in code
