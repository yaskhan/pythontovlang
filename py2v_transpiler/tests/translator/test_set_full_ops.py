import unittest
import ast
from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.core.analyzer import TypeInference

class MockEmitter:
    def __init__(self): self.imports = []
    def add_import(self, imp): self.imports.append(imp)

class MockCoroutineHandler:
    def is_generator(self, name): return False

class TestTranslator(ExpressionsMixin, LiteralsMixin, TranslatorBase):
    def __init__(self, type_inference):
        super().__init__(type_inference)
        self.output = []
        self.coroutine_handler = MockCoroutineHandler()
        self.emitter = MockEmitter()
        self.mapper = None
    
    def visit_Name(self, node):
        return node.id

class TestSetFullOps(unittest.TestCase):
    def setUp(self):
        self.ti = TypeInference()
        self.translator = TestTranslator(self.ti)

    def translate_expr(self, code):
        tree = ast.parse(code)
        node = tree.body[0].value
        return self.translator.visit(node)

    def test_set_methods_mutation(self):
        self.ti.type_map["s"] = "map[int]bool"
        self.assertEqual(self.translate_expr("s.add(1)"), "s[1] = true")
        self.assertEqual(self.translate_expr("s.remove(1)"), "py_set_remove(mut s, 1)")
        self.assertEqual(self.translate_expr("s.discard(1)"), "s.delete(1)")
        self.assertEqual(self.translate_expr("s.pop()"), "py_set_pop(mut s)")
        self.assertEqual(self.translate_expr("s.clear()"), "/* s.clear() */ s = {}")
        self.assertEqual(self.translate_expr("s.copy()"), "s.clone()")

    def test_set_theoretic_methods(self):
        self.ti.type_map["a"] = "map[int]bool"
        self.assertEqual(self.translate_expr("a.union(b)"), "py_set_union(a, b)")
        self.assertEqual(self.translate_expr("a.intersection(b)"), "py_set_intersection(a, b)")
        self.assertEqual(self.translate_expr("a.difference(b)"), "py_set_difference(a, b)")
        self.assertEqual(self.translate_expr("a.symmetric_difference(b)"), "py_set_xor(a, b)")

    def test_set_update_methods(self):
        self.ti.type_map["a"] = "map[int]bool"
        self.assertEqual(self.translate_expr("a.update(b)"), "py_set_update(mut a, b)")
        self.assertEqual(self.translate_expr("a.intersection_update(b)"), "py_set_intersection_update(mut a, b)")
        self.assertEqual(self.translate_expr("a.difference_update(b)"), "py_set_difference_update(mut a, b)")
        self.assertEqual(self.translate_expr("a.symmetric_difference_update(b)"), "py_set_xor_update(mut a, b)")

    def test_set_comparisons(self):
        self.ti.type_map["a"] = "map[int]bool"
        self.ti.type_map["b"] = "map[int]bool"
        self.assertEqual(self.translate_expr("a.issubset(b)"), "py_set_subset(a, b)")
        self.assertEqual(self.translate_expr("a.issuperset(b)"), "py_set_superset(a, b)")
        self.assertEqual(self.translate_expr("a.isdisjoint(b)"), "py_set_isdisjoint(a, b)")
        
        self.assertEqual(self.translate_expr("a < b"), "py_set_strict_subset(a, b)")
        self.assertEqual(self.translate_expr("a > b"), "py_set_strict_superset(a, b)")

    def test_set_creation_inference(self):
        self.assertEqual(self.translate_expr("set([1, 2])"), "py_set_from_list[map[int]bool]([1, 2])")
        self.assertEqual(self.translate_expr("set()"), "map[string]bool{}")

if __name__ == '__main__':
    unittest.main()
