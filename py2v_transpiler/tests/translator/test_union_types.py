
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
        return self.translator.emitter.emit()

    def test_union_arg(self):
        source = "def f(x: int | str): pass"
        result = self.transpile(source)
        # Should be 'x any' not 'x int | string'
        self.assertIn("x any", result)

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
        # Should use 'any' default value? Or just 'x := ...'
        # Current logic tries to map type to default value.
        # If type is 'any', default is '0'? No, 'any' in V?
        # V variables cannot be just 'any' without initialization?
        # Actually `x := any(0)`. Or `x := 0`.
        # If we map to 'any', we need a default.
        # My map logic returns 'any' for 'any'.
        # Let's see what happens.
        # Expect 'x := 0' (fallback) or something valid.
        self.assertNotIn("int | string", result)

if __name__ == '__main__':
    unittest.main()
