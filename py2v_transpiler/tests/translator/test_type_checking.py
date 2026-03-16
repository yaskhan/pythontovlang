import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestTypeChecking(unittest.TestCase):
    def setUp(self):
        self.analyzer = TypeInference()
        self.translator = VNodeVisitor(self.analyzer)

    def transpile(self, source: str) -> str:
        tree = ast.parse(source)
        self.analyzer.analyze(tree)
        return self.translator.visit_Module(tree)

    def test_type_checking_skipped(self):
        source = """
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from other_module import SomeType
def foo(x: int) -> int:
    return x
"""
        output = self.transpile(source)
        self.assertNotIn("TYPE_CHECKING", output)
        self.assertNotIn("SomeType", output)
        self.assertIn("fn foo(x int) int {", output)

    def test_typing_type_checking_skipped(self):
        source = """
import typing
if typing.TYPE_CHECKING:
    import heavy_module
x = 10
"""
        output = self.transpile(source)
        self.assertNotIn("typing.TYPE_CHECKING", output)
        self.assertNotIn("heavy_module", output)
        self.assertIn("x := 10", output)

    def test_t_type_checking_skipped(self):
        source = """
import typing as t
if t.TYPE_CHECKING:
    x: int = 1
y = 2
"""
        output = self.transpile(source)
        self.assertNotIn("t.TYPE_CHECKING", output)
        self.assertNotIn("x := 1", output)
        self.assertIn("y := 2", output)

    def test_nested_type_checking_skipped(self):
        source = """
if True:
    if TYPE_CHECKING:
        from x import Y
    print(1)
"""
        output = self.transpile(source)
        self.assertNotIn("TYPE_CHECKING", output)
        self.assertNotIn("from x import Y", output)
        self.assertIn("println", output)
        self.assertIn("1", output)

if __name__ == "__main__":
    unittest.main()
