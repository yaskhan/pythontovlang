
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestLoopElse(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_for_else(self):
        source = """
for i in range(5):
    if i == 3:
        break
else:
    print("finished")
"""
        result = self.transpile(source)
        self.assertIn("mut py_loop_completed_", result)
        self.assertIn("if py_loop_completed_", result)
        self.assertIn("break", result)
        # We expect the flag to be set to false before break
        # regex or strict check difficult due to generated IDs
        # but we check if assignment exists
        self.assertIn(" = false", result)

    def test_while_else(self):
        source = """
while True:
    break
else:
    print("finished")
"""
        result = self.transpile(source)
        self.assertIn("mut py_loop_completed_", result)
        self.assertIn("if py_loop_completed_", result)

if __name__ == '__main__':
    unittest.main()
