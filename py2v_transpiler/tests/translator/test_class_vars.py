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

    # Should be in Meta struct
    assert "pub struct VehicleMeta {" in code
    assert "wheels int = 4" in code
    assert "brand string = 'Generic'" in code

    # Should be singleton instance
    assert "pub const Vehicle_meta = &VehicleMeta{}" in code

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

    # Both instance and class access should be redirected to Meta singleton
    assert "println('${Vehicle_meta.wheels}')" in code

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

    # Should find wheels in Vehicle and use Vehicle_meta singleton
    assert "println('${Vehicle_meta.wheels}')" in code
