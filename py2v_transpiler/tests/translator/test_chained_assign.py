
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestChainedAssign(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_chained_assign(self):
        source = """
a = b = 1
"""
        result = self.transpile(source)
        # Expected:
        # _assign_tmp_0 := 1
        # a := _assign_tmp_0
        # b := _assign_tmp_0
        self.assertIn("_assign_tmp_", result)
        self.assertIn("a :=", result)
        self.assertIn("b :=", result)

if __name__ == '__main__':
    unittest.main()
