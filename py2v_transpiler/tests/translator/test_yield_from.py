
import ast
import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class TestYieldFrom(unittest.TestCase):
    def setUp(self):
        self.type_inference = TypeInference()
        self.translator = VNodeVisitor(self.type_inference)

    def transpile(self, source):
        tree = ast.parse(source)
        self.translator.visit(tree)
        return self.translator.emitter.emit()

    def test_yield_from(self):
        source = """
def sub_gen():
    yield 1
    yield 2

def gen():
    yield from sub_gen()
"""
        result = self.transpile(source)
        self.assertIn("for v in sub_gen() {", result)
        self.assertIn("ch <- v", result)

if __name__ == '__main__':
    unittest.main()
