
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestHelpersInjection(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit() + "\n" + self.translator.emitter.emit_helpers()

    def test_list_concat_injection(self):
        # We simulate usage by setting the flag manually or expecting unconditional injection
        # For this test, we assume the translator will have a flag 'used_list_concat'
        self.translator.used_list_concat = True
        source = "pass"
        result = self.transpile(source)
        self.assertIn("fn py_list_concat", result)

    def test_dict_merge_injection(self):
        self.translator.used_dict_merge = True
        source = "pass"
        result = self.transpile(source)
        self.assertIn("fn py_dict_merge", result)

if __name__ == '__main__':
    unittest.main()
