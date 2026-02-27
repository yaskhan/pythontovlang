
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestLiteralsUnderscores(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_underscores_int(self):
        source = "x = 1_000"
        result = self.transpile(source)
        # Python parser swallows underscores. AST has value 1000.
        # Transpiler outputs "x := 1000" (or similar default formatting)
        self.assertIn("1000", result)

    def test_underscores_float(self):
        source = "x = 1_000.50"
        result = self.transpile(source)
        self.assertIn("1000.5", result)

if __name__ == '__main__':
    unittest.main()
