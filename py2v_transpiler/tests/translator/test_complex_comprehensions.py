import unittest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

class TestComplexComprehensions(unittest.TestCase):
    def translate(self, code):
        tree = ast.parse(code)
        analyzer = TypeInference()
        analyzer.analyze(tree)
        translator = VNodeVisitor(analyzer)
        return translator.visit_Module(tree)

    def test_nested_list_comprehension(self):
        code = "matrix = [[1, 2], [3, 4]]; flattened = [x for row in matrix for x in row]"
        v_code = self.translate(code)
        self.assertIn("for row in matrix {", v_code)
        self.assertIn("for x in row {", v_code)
        self.assertIn("flattened << x", v_code)

    def test_list_comp_multiple_ifs(self):
        code = "res = [x for x in range(10) if x > 2 if x < 8]"
        v_code = self.translate(code)
        self.assertIn("if x > 2 {", v_code)
        self.assertIn("if x < 8 {", v_code)
        self.assertIn("res << x", v_code)

    def test_nested_dict_comprehension(self):
        code = "matrix = [[1, 2], [3, 4]]; res = {str(x): x for row in matrix for x in row if x % 2 == 0}"
        v_code = self.translate(code)
        self.assertIn("for row in matrix {", v_code)
        self.assertIn("for x in row {", v_code)
        self.assertIn("if x % 2 == 0 {", v_code)
        self.assertIn("res[x.str()] = x", v_code)

    def test_nested_set_comprehension(self):
        code = "matrix = [[1, 2], [1, 2]]; res = {x for row in matrix for x in row}"
        v_code = self.translate(code)
        self.assertIn("for row in matrix {", v_code)
        self.assertIn("for x in row {", v_code)
        self.assertIn("res[x] = true", v_code)

    def test_complex_zip_comprehension(self):
        code = "res = [x + y for x, y in zip([1, 2], [3, 4]) if x > 1]"
        v_code = self.translate(code)
        self.assertIn("for py_i_1, py_v1_1 in py_zip_it1_1 {", v_code)
        self.assertIn("if x > 1 {", v_code)
        self.assertIn("res << x + y", v_code)

    def test_triple_nested_list_comp(self):
        code = "res = [z for x in a for y in x for z in y]"
        v_code = self.translate(code)
        self.assertIn("for x in a {", v_code)
        self.assertIn("for y in x {", v_code)
        self.assertIn("for z in y {", v_code)
        self.assertIn("res << z", v_code)
