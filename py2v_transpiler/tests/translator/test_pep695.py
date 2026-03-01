import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestPEP695(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.type_inference.analyze(tree)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_generic_type_alias_dict(self):
        source = "type Alias[T] = dict[str, T]\nx: Alias[int] = {'a': 1}"
        result = self.transpile(source)
        self.assertIn("type Alias[T] = map[string]T", result)
        self.assertIn("x := Alias[int]{", result)

    def test_generic_type_alias_list(self):
        source = "type ListAlias[T] = list[T]\nx: ListAlias[int] = [1]"
        result = self.transpile(source)
        self.assertIn("type ListAlias[T] = []T", result)
        self.assertIn("mut x := ListAlias[int]{cap: 1}", result)

if __name__ == '__main__':
    unittest.main()
