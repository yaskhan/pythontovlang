import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestConstructors(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        # Populate defined_classes by visiting the module
        self.translator.visit(tree)
        # We need to look at the collected output
        # But wait, visit_Module appends to emitter.
        # Let's use a helper that gets the full output.
        return self.translator.emitter.emit()

    def test_new_only(self):
        source = """
class Decimal:
    def __new__(cls, value: str) -> "Decimal":
        return object.__new__(cls)
"""
        result = self.transpile(source)
        self.assertIn("fn new_decimal(value string) Decimal {", result)
        self.assertIn("return Decimal{}", result)
        # Should NOT have __new__ method
        self.assertNotIn("__new__", result)

    def test_init_only(self):
        source = """
class Point:
    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y
"""
        result = self.transpile(source)
        self.assertIn("fn new_point(x int, y int) Point {", result)
        self.assertIn("mut self := Point{}", result)

    def test_new_and_init(self):
        source = """
class Decimal:
    def __new__(cls, value: str) -> "Decimal":
        return Decimal()

    def __init__(self, value: str):
        self.value = value
"""
        result = self.transpile(source)
        self.assertIn("fn new_decimal(value string) Decimal {", result)
        self.assertIn("return new_decimal()", result)
        self.assertIn("fn (self Decimal) init(value string) {", result)

    def test_instantiation_new(self):
        source = """
class Decimal:
    def __new__(cls, value: str):
        return Decimal()
d = Decimal("1.2")
"""
        # We need visit_Module to see the main block
        tree = ast.parse(source)
        res_module = self.translator.visit_Module(tree)
        self.assertIn("d := new_decimal('1.2')", res_module)

    def test_instantiation_init(self):
        source = """
class Point:
    def __init__(self, x: int):
        self.x = x
p = Point(1)
"""
        tree = ast.parse(source)
        res_module = self.translator.visit_Module(tree)
        self.assertIn("p := new_point(1)", res_module)

if __name__ == '__main__':
    unittest.main()
