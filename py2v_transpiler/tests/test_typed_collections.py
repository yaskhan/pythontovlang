import unittest
import os
import subprocess
import sys

def transpile(source_code: str, filename: str = "test.py") -> str:
    with open(filename, "w") as f:
        f.write(source_code)

    subprocess.run([sys.executable, "-m", "py2v_transpiler.main", filename], check=True)

    v_filename = filename.replace(".py", ".v")
    with open(v_filename, "r") as f:
        v_code = f.read()

    # Cleanup
    if os.path.exists(filename): os.remove(filename)
    if os.path.exists(v_filename): os.remove(v_filename)
    helpers = filename.replace(".py", "_helpers.v")
    if os.path.exists(helpers): os.remove(helpers)

    return v_code

class TestTypedCollections(unittest.TestCase):
    def test_homogeneous_list_int(self):
        code = "l = [1, 2, 3]"
        v_code = transpile(code, "test_list_int.py")
        # Transpiler now correctly uses square brackets for elements
        self.assertIn("l := [1, 2, 3]", v_code)

    def test_homogeneous_list_str(self):
        code = "l = ['a', 'b']"
        v_code = transpile(code, "test_list_str.py")
        self.assertIn("l := ['a', 'b']", v_code)

    def test_mixed_list(self):
        code = "l = [1, 'a']"
        v_code = transpile(code, "test_list_mixed.py")
        self.assertIn("l := [1, 'a']", v_code)

    def test_homogeneous_dict_str_int(self):
        code = "d = {'a': 1, 'b': 2}"
        v_code = transpile(code, "test_dict_str_int.py")
        self.assertIn("d := {'a': 1, 'b': 2}", v_code)

    def test_homogeneous_dict_int_str(self):
        code = "d = {1: 'a', 2: 'b'}"
        v_code = transpile(code, "test_dict_int_str.py")
        self.assertIn("d := {1: 'a', 2: 'b'}", v_code)

    def test_empty_list_with_annotation(self):
        code = "l: list[float] = []"
        v_code = transpile(code, "test_empty_list_ann.py")
        self.assertIn("l := []f64{}", v_code)

    def test_empty_dict_with_annotation(self):
        code = "d: dict[str, float] = {}"
        v_code = transpile(code, "test_empty_dict_ann.py")
        self.assertIn("d := map[string]f64{}", v_code)

    def test_list_append_inference(self):
        # This tests AliasInferer and TypeInference integration
        # Note: the current AliasInferer might be limited to certain patterns
        code = """
items = []
items.append(1)
"""
        # TypeInference should see items = [] and items.append(1) -> []int
        v_code = transpile(code, "test_list_append.py")
        self.assertIn("items := []int{}", v_code)

if __name__ == "__main__":
    unittest.main()
