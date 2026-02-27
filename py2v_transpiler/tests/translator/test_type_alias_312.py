
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestTypeAlias312(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_type_alias_statement(self):
        # type T = int
        # Need Python 3.12+ parser to parse this syntax.
        # If env is 3.12, it works.
        try:
            source = "type T = int"
            result = self.transpile(source)
            self.assertIn("type T = int", result)
        except SyntaxError:
            print("Skipping Python 3.12 test (syntax not supported)")

    def test_generic_type_alias(self):
        # type T[U] = list[U]
        try:
            source = "type T[U] = list[U]"
            result = self.transpile(source)
            # V generic type alias: type T[U] = []U
            self.assertIn("type T[U] = []U", result)
        except SyntaxError:
            pass

if __name__ == '__main__':
    unittest.main()
