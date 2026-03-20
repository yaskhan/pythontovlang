import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_class_variables_definition():
    source = """
class Vehicle:
    wheels = 4
    brand: str = "Generic"
"""
    analyzer = TypeInference()
    tree = ast.parse(source)
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer)
    code = visitor.visit_Module(tree)

    # Should NOT be in struct anymore as instance field
    # We check that the main struct is empty
    assert "struct Vehicle {\n}" in code

    # Should be in Meta struct
    assert "pub struct VehicleMeta {" in code
    assert "wheels int = 4" in code
    assert "brand string = 'Generic'" in code

    # Should be meta constant
    assert "pub const Vehicle_meta = &VehicleMeta{}" in code

def test_class_variables_access():
    source = """
class Vehicle:
    wheels = 4

v = Vehicle()
print(v.wheels)
print(Vehicle.wheels)
"""
    analyzer = TypeInference()
    tree = ast.parse(source)
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer)
    code = visitor.visit_Module(tree)

    # All access should be via Vehicle_meta
    assert "println('${Vehicle_meta.wheels}')" in code

def test_inherited_class_variable_access():
    source = """
class Vehicle:
    wheels = 4

class Car(Vehicle):
    pass

print(Car.wheels)
"""
    analyzer = TypeInference()
    tree = ast.parse(source)
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer)
    code = visitor.visit_Module(tree)

    # Should find wheels in Vehicle and use Vehicle_meta constant
    assert "println('${Vehicle_meta.wheels}')" in code

def test_class_variable_assignment():
    source = """
class Vehicle:
    wheels = 4

Vehicle.wheels = 5
v = Vehicle()
v.wheels = 6
"""
    analyzer = TypeInference()
    tree = ast.parse(source)
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer)
    code = visitor.visit_Module(tree)

    # Assignments should be redirected to Vehicle_meta
    assert "Vehicle_meta.wheels = 5" in code
    assert "Vehicle_meta.wheels = 6" in code
