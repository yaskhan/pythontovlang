import unittest
import os
import tempfile
import shutil
from py2v_transpiler.main import transpile_file
from py2v_transpiler.config import TranspilerConfig

class TestVariadicTyping(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.config = TranspilerConfig(mypy_enabled=True)

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def _transpile_and_get_v(self, py_content, filename="test.py"):
        py_path = os.path.join(self.test_dir, filename)
        with open(py_path, "w") as f:
            f.write(py_content)

        success = transpile_file(py_path, self.config)
        self.assertTrue(success)

        v_path = os.path.join(self.test_dir, "test.v")
        with open(v_path, "r") as f:
            return f.read()

    def test_annotated_varargs(self):
        py_code = """
def foo(*args: int):
    for arg in args:
        print(arg)
"""
        v_code = self._transpile_and_get_v(py_code)
        self.assertIn("fn foo(args ...int) {", v_code)

    def test_annotated_kwargs(self):
        py_code = """
def foo(**kwargs: float):
    for k, v in kwargs.items():
        print(k, v)
"""
        v_code = self._transpile_and_get_v(py_code)
        self.assertIn("fn foo(kwargs map[string]f64) {", v_code)

    def test_default_any_varargs(self):
        py_code = """
def foo(*args):
    pass
"""
        v_code = self._transpile_and_get_v(py_code)
        # Should default to Any if no inference possible
        self.assertIn("fn foo(args ...Any) {", v_code)

    def test_default_any_kwargs(self):
        py_code = """
def foo(**kwargs):
    pass
"""
        v_code = self._transpile_and_get_v(py_code)
        # Should default to map[string]Any
        self.assertIn("fn foo(kwargs map[string]Any) {", v_code)

if __name__ == "__main__":
    unittest.main()
