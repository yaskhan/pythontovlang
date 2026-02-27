
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
        # Note: visit_Call now injects spawn logic, so sub_gen() returns a PyGenerator object.
        # But visit_Call returns a VARIABLE name, not "sub_gen()".
        # So "for v in sub_gen() {" will look like "gen_1 := ...; spawn sub_gen(...); for v in gen_1 {"

        # We check for loop and py_yield
        self.assertIn("spawn sub_gen(", result)
        self.assertIn("for v in gen_", result)
        self.assertIn("py_yield(ch_out, ch_in, v)", result)

if __name__ == '__main__':
    unittest.main()
