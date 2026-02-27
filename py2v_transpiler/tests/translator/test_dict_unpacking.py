
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestDictUnpacking(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_dict_unpacking(self):
        source = "d = {'a': 1, **extra, 'b': 2}"
        # Chunks: {'a': 1}, extra, {'b': 2}
        # py_dict_merge({'a': 1}, extra, {'b': 2})
        result = self.transpile(source)
        self.assertIn("py_dict_merge", result)
        # Check structure
        # V map literals: map[string]int{'a': 1}
        self.assertIn("'a': 1", result)
        self.assertIn("extra", result)
        self.assertIn("'b': 2", result)

if __name__ == '__main__':
    unittest.main()
