
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestTryElse(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_try_else(self):
        source = """
try:
    pass
except:
    pass
else:
    x = 1
"""
        result = self.transpile(source)
        # Check that x := 1 is emitted and active
        self.assertIn("x := 1", result)
        # Check for the comment
        self.assertIn("// Python 'else' block", result)
        # Verify x := 1 is NOT commented out (simple check)
        self.assertNotIn("// x := 1", result)

if __name__ == '__main__':
    unittest.main()
