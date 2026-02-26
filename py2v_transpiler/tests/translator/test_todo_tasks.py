import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestTodoTasks(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        # Fix: use emitter output, not internal buffer which is cleared
        return self.translator.emitter.emit()

    def test_metaclass(self):
        source = """
class MyMeta(type):
    pass
class MyClass(metaclass=MyMeta):
    pass
"""
        result = self.transpile(source)
        self.assertIn("// Metaclass: MyMeta", result)
        self.assertIn("struct MyClass {", result)

    def test_slots(self):
        source = """
class Point:
    __slots__ = ['x', 'y']
"""
        result = self.transpile(source)
        self.assertIn("struct Point {", result)
        self.assertIn("x int", result)
        self.assertIn("y int", result)

    def test_descriptors(self):
        source = """
class Descriptor:
    def __get__(self, instance, owner):
        pass
    def __set__(self, instance, value):
        pass
    def __delete__(self, instance):
        pass
"""
        result = self.transpile(source)
        self.assertIn("fn (self Descriptor) get(instance int, owner int) {", result)
        self.assertIn("fn (self Descriptor) set(instance int, value int) {", result)
        self.assertIn("fn (self Descriptor) delete(instance int) {", result)

    def test_new_method(self):
        source = """
class MyClass:
    def __new__(cls):
        pass
"""
        result = self.transpile(source)
        self.assertIn("fn new_MyClass_new() {", result)

    def test_ellipsis_literal(self):
        source = """
def stub():
    ...
"""
        result = self.transpile(source)
        self.assertIn("/* ... */", result)

    def test_ellipsis_slice(self):
        source = """
def foo():
    a = [1]
    b = a[...]
"""
        result = self.transpile(source)
        self.assertIn("[/* ... */]", result)

    def test_future_annotations(self):
        source = """
from __future__ import annotations
x: int = 1
"""
        result = self.transpile(source)
        self.assertNotIn("import __future__", result)
        self.assertIn("x := 1", result)

if __name__ == '__main__':
    unittest.main()
