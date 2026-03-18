import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestSliceReverseInjection(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()

    def transpile(self, source):
        # Create a fresh translator for each test
        self.translator = VNodeVisitor(self.type_inference)
        tree = ast.parse(source)
        # We need to analyze before visit for proper type inference
        self.type_inference.visit(tree)
        return self.translator.visit(tree)

    def test_string_reverse_injection(self):
        source = 's = "Hello"\nrev = s[::-1]'
        result = self.transpile(source)
        self.assertIn("py_str_reverse(s)", result)
        # Check if helper was registered
        self.assertIn("py_str_reverse", self.translator.used_builtins)

    def test_list_reverse_injection(self):
        source = 'l = [1, 2, 3]\nrev = l[::-1]'
        result = self.transpile(source)
        self.assertIn("py_list_reverse(l)", result)
        self.assertIn("py_list_reverse", self.translator.used_builtins)

    def test_string_step_slice_injection(self):
        source = 's = "Programming"\nstep = s[::2]'
        result = self.transpile(source)
        self.assertIn("py_str_slice(s, none, none, 2)", result)
        self.assertIn("py_str_slice", self.translator.used_builtins)

    def test_list_step_slice_injection(self):
        source = 'l = [1, 2, 3, 4, 5]\nstep = l[1:4:2]'
        result = self.transpile(source)
        self.assertIn("py_list_slice(l, 1, 4, 2)", result)
        self.assertIn("py_list_slice", self.translator.used_builtins)

if __name__ == "__main__":
    unittest.main()
