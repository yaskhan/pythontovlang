from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.core.analyzer import TypeInference
import ast
import unittest

class TestSetOperations(unittest.TestCase):
    def setUp(self):
        self.ti = TypeInference()
        class TestTranslator(ExpressionsMixin, LiteralsMixin, TranslatorBase):
            def __init__(self, type_inference):
                super().__init__(type_inference)
        self.translator = TestTranslator(self.ti)

    def translate(self, code):
        tree = ast.parse(code)
        node = tree.body[0].value
        return self.translator.visit(node)

    def test_set_union(self):
        code = "{1, 2} | {2, 3}"
        result = self.translate(code)
        self.assertEqual(result, "py_set_union({1: true, 2: true}, {2: true, 3: true})")
        self.assertIn("py_set_union", self.translator.used_builtins)

    def test_set_intersection(self):
        code = "{1, 2} & {2, 3}"
        result = self.translate(code)
        self.assertEqual(result, "py_set_intersection({1: true, 2: true}, {2: true, 3: true})")
        self.assertIn("py_set_intersection", self.translator.used_builtins)

    def test_set_difference(self):
        code = "{1, 2} - {2, 3}"
        result = self.translate(code)
        self.assertEqual(result, "py_set_difference({1: true, 2: true}, {2: true, 3: true})")
        self.assertIn("py_set_difference", self.translator.used_builtins)

    def test_set_xor(self):
        code = "{1, 2} ^ {2, 3}"
        result = self.translate(code)
        self.assertEqual(result, "py_set_xor({1: true, 2: true}, {2: true, 3: true})")
        self.assertIn("py_set_xor", self.translator.used_builtins)

    def test_mixed_types_no_set_op(self):
        # If one side is not a set, it should not use py_set_union
        # Note: _guess_type for {1, 2} is map[int]bool
        # _guess_type for 1 is int
        # V would error anyway, but we want to see it doesn't use the helper if not both sets.
        code = "{1, 2} | 1"
        result = self.translate(code)
        self.assertEqual(result, "{1: true, 2: true} | 1")

if __name__ == "__main__":
    unittest.main()
