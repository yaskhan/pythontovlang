
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
        # Expect 'x := mgr' and 'defer { x.close() }'
        self.assertIn("x := mgr", result)
        self.assertIn("defer { x.close() }", result)

    def test_async_with_no_var(self):
        source = """
async def foo():
    async with mgr:
        pass
"""
        result = self.transpile(source)
        # Expect temp var and defer
        self.assertIn("defer {", result)
        self.assertIn(".close() }", result)

if __name__ == '__main__':
    unittest.main()
