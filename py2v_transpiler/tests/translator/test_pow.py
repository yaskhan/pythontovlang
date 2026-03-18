import unittest
from py2v_transpiler.main import Transpiler

class TestPow(unittest.TestCase):
    def test_pow_integers(self):
        code = "a = 2 ** 10"
        transpiler = Transpiler()
        output = transpiler.transpile(code)
        self.assertIn("import math", output)
        self.assertIn("a := int(math.powi(f64(2), 10))", output)

    def test_pow_floats(self):
        code = "b = 2.5 ** 2"
        transpiler = Transpiler()
        output = transpiler.transpile(code)
        self.assertIn("b := math.pow(2.5, f64(2))", output)

    def test_pow_mixed(self):
        code = "c = 2 ** 2.5"
        transpiler = Transpiler()
        output = transpiler.transpile(code)
        self.assertIn("c := math.pow(f64(2), 2.5)", output)

if __name__ == '__main__':
    unittest.main()
