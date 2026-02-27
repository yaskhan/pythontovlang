
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestAsyncFor(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_async_for(self):
        source = """
async def process():
    async for item in async_gen():
        pass
"""
        result = self.transpile(source)
        # Expect for loop over channel
        self.assertIn("for item in async_gen() {", result)

    def test_async_for_nested_in_loop(self):
        # Regression test for break handling
        source = """
async def process():
    for x in range(10):
        async for item in async_gen():
            break
"""
        result = self.transpile(source)
        self.assertIn("for item in async_gen() {", result)
        self.assertIn("break", result)


if __name__ == '__main__':
    unittest.main()
