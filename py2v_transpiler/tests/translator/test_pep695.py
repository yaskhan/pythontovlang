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
        try:
            result = self.transpile(source)
            self.assertIn("type Alias[T] = map[string]T", result)
        except SyntaxError:
            pass

    def test_generic_type_alias_list(self):
        source = "type ListAlias[T] = list[T]\nx: ListAlias[int] = [1]"
        try:
            result = self.transpile(source)
            self.assertIn("type ListAlias[T] = []T", result)
            # Note: it will just be `x := [1]`, it does not emit `ListAlias[int]{cap: 1}` because map_python_type_to_v returns ListAlias[int], not []int
        except SyntaxError:
            pass

if __name__ == '__main__':
    unittest.main()
