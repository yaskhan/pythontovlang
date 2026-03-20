module main

// @line: test_class_vars.py:5:0
pub fn test_class_variables_definition() {
    mut source := '
class Vehicle:
    wheels = 4
    brand: str = "Generic"
'
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    mut tree := ast.parse(source)
    analyzer.analyze(tree)
    mut visitor := py2v_transpiler.core.translator.VNodeVisitor(analyzer)
    mut code := visitor.visit_Module(tree)
    assert 'struct Vehicle {
}' in code
    assert 'pub struct VehicleMeta {' in code
    assert 'wheels int = 4' in code
    assert 'brand string = \'Generic\'' in code
    assert 'pub const Vehicle_meta = &VehicleMeta{}' in code
}
// @line: test_class_vars.py:29:0
pub fn test_class_variables_access() {
    mut source := '
class Vehicle:
    wheels = 4

v = Vehicle()
print(v.wheels)
print(Vehicle.wheels)
'
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    mut tree := ast.parse(source)
    analyzer.analyze(tree)
    mut visitor := py2v_transpiler.core.translator.VNodeVisitor(analyzer)
    mut code := visitor.visit_Module(tree)
    assert 'println(\'${Vehicle_meta.wheels}\')' in code
}
// @line: test_class_vars.py:47:0
pub fn test_inherited_class_variable_access() {
    mut source := '
class Vehicle:
    wheels = 4

class Car(Vehicle):
    pass

print(Car.wheels)
'
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    mut tree := ast.parse(source)
    analyzer.analyze(tree)
    mut visitor := py2v_transpiler.core.translator.VNodeVisitor(analyzer)
    mut code := visitor.visit_Module(tree)
    assert 'println(\'${Vehicle_meta.wheels}\')' in code
}
// @line: test_class_vars.py:66:0
pub fn test_class_variable_assignment() {
    mut source := '
class Vehicle:
    wheels = 4

Vehicle.wheels = 5
v = Vehicle()
v.wheels = 6
'
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    mut tree := ast.parse(source)
    analyzer.analyze(tree)
    mut visitor := py2v_transpiler.core.translator.VNodeVisitor(analyzer)
    mut code := visitor.visit_Module(tree)
    assert 'Vehicle_meta.wheels = 5' in code
    assert 'Vehicle_meta.wheels = 6' in code
}
