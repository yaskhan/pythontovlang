import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestSliceHelpersInjection(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit() + "\n" + self.translator.emitter.emit_helpers()

    def test_slice_helpers_injection(self):
        source = "l = [1, 2, 3]\nl[1:2] = [4]"
        result = self.transpile(source)
        self.assertIn("fn (mut a []T) delete_many[T]", result)
        self.assertIn("fn (mut a []T) insert_many[T]", result)

if __name__ == '__main__':
    unittest.main()
