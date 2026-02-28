import unittest
from py2v_transpiler.main import Transpiler

class TestVariadic(unittest.TestCase):
    def test_variadic_args(self):
        code = """
def homogeneous(*args: int, **kwargs: int):
    pass

def heterogeneous(*args: 'Any', **kwargs: 'Any'):
    pass

def unannotated(*args, **kwargs):
    pass
"""
        transpiler = Transpiler()
        output = transpiler.transpile(code)

        self.assertIn("fn homogeneous(args ...int, kwargs map[string]int) {", output)
        self.assertIn("fn heterogeneous(args ...Any, kwargs map[string]Any) {", output)
        self.assertIn("fn unannotated(args ...Any, kwargs map[string]Any) {", output)

if __name__ == '__main__':
    unittest.main()
