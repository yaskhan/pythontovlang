
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestAsyncWith(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_async_with(self):
        source = """
async def foo():
    async with mgr as x:
        pass
"""
        result = self.transpile(source)
        # Expect temp mgr, defer exit, and x := enter
        self.assertIn("ctx_mgr_0 := mgr", result)
        self.assertIn("defer { ctx_mgr_0.exit(none, none, none) }", result)
        self.assertIn("x := ctx_mgr_0.enter()", result)

    def test_async_with_no_var(self):
        source = """
async def foo():
    async with mgr:
        pass
"""
        result = self.transpile(source)
        # Expect temp var and defer
        self.assertIn("defer {", result)
        self.assertIn(".exit(none, none, none) }", result)

if __name__ == '__main__':
    unittest.main()
