
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestSuperNoArg(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_super_no_arg(self):
        source = """
class Parent:
    def foo(self):
        pass

class Child(Parent):
    def foo(self):
        super().foo()
"""
        result = self.transpile(source)
        # Expect self.Parent.foo()
        self.assertIn("self.Parent.foo()", result)

if __name__ == '__main__':
    unittest.main()
