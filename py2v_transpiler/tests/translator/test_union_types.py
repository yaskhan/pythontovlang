
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestUnionTypes(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit() + "\n" + self.translator.emitter.emit_helpers()

    def test_union_arg(self):
        source = "def f(x: int | str): pass"
        result = self.transpile(source)
        # Should be 'x SumType_IntString'
        self.assertIn("type SumType_IntString = int | string", result)
        self.assertIn("x SumType_IntString", result)

    def test_union_deduplication(self):
        source = """
def f(x: int | str, y: str | int): pass
"""
        result = self.transpile(source)
        # Should deduplicate and only generate SumType_IntString once
        self.assertEqual(result.count("type SumType_IntString = int | string"), 1)
        self.assertIn("fn f(x SumType_IntString, y SumType_IntString)", result)

    def test_optional_union_arg(self):
        source = "def f(x: int | None): pass"
        result = self.transpile(source)
        # Should be 'x ?int'
        self.assertIn("x ?int", result)

    def test_type_alias_union(self):
        source = "MyType = int | str"
        result = self.transpile(source)
        # Should be 'type MyType = int | string' (allowed in type alias)
        self.assertIn("type MyType = int | string", result)

    def test_new_type_union(self):
        source = "MyType = NewType('MyType', int | str)"
        result = self.transpile(source)
        self.assertIn("type MyType = int | string", result)

    def test_ann_assign_union(self):
        source = "x: int | str = 1"
        result = self.transpile(source)
        # Annotations on variables are ignored for declaration usually, but if used for initialization?
        # x := 1. The type is inferred from value.
        # But if no value? x: int | str.
        # We need to map to default value.
        pass

    def test_ann_assign_union_no_init(self):
        source = "x: int | str"
        result = self.transpile(source)
        # Without initialization, it falls back to a simple default type/value.
        # Currently it seems it defaults to 0.
        self.assertIn("x := 0", result)

if __name__ == '__main__':
    unittest.main()
