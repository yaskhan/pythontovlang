
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestListUnpacking(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_list_concat(self):
        source = "x = [1, *a, 2]"
        result = self.transpile(source)
        # Should be py_list_concat([1], a, [2])
        # Note: visit_List emits [1] as [1], but py_list_concat args.
        self.assertIn("py_list_concat", result)
        self.assertIn("([1], a, [2])", result)

    def test_tuple_concat(self):
        source = "x = (1, *a)"
        result = self.transpile(source)
        # Tuple usually transpiles to array.
        # py_list_concat([1], a)
        self.assertIn("py_list_concat([1], a)", result)

    def test_set_unpacking(self):
        source = "x = {1, *a}"
        # Set {1} -> {1: true}
        # Unpacked *a -> a (assuming a is map[int]bool or compatible)
        # py_dict_merge({1: true}, a)
        result = self.transpile(source)
        self.assertIn("py_dict_merge", result)
        self.assertIn("{1: true}", result)
        # We check order? Dict merge order not guaranteed but args order is.
        # py_dict_merge(..., a)
        # Regex or flexible matching might be needed
        self.assertIn(", a)", result)

if __name__ == '__main__':
    unittest.main()
