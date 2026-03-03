import ast
import unittest
from py2v_transpiler.core.parser import PyASTParser

class TestTStrings(unittest.TestCase):
    def test_basic_t_string(self):
        source = 'template = t"Hello {name}"'
        parser = PyASTParser()
        tree = parser.parse(source)

        assign = tree.body[0]
        self.assertIsInstance(assign.value, ast.Call)
        self.assertEqual(assign.value.func.id, "py2v_t_string")
        self.assertIsInstance(assign.value.args[0], ast.JoinedStr)
        self.assertEqual(len(assign.value.args[0].values), 2)
        self.assertIsInstance(assign.value.args[0].values[0], ast.Constant)
        self.assertEqual(assign.value.args[0].values[0].value, "Hello ")
        self.assertIsInstance(assign.value.args[0].values[1], ast.FormattedValue)

    def test_uppercase_t_string(self):
        source = 'template = T"Hello {name}"'
        parser = PyASTParser()
        tree = parser.parse(source)

        assign = tree.body[0]
        self.assertIsInstance(assign.value, ast.Call)
        self.assertEqual(assign.value.func.id, "py2v_t_string")
        self.assertIsInstance(assign.value.args[0], ast.JoinedStr)

    def test_raw_t_string(self):
        source = r'template = rt"Hello \n {name}"'
        parser = PyASTParser()
        tree = parser.parse(source)

        assign = tree.body[0]
        self.assertIsInstance(assign.value, ast.Call)
        self.assertEqual(assign.value.func.id, "py2v_t_string")
        self.assertIsInstance(assign.value.args[0], ast.JoinedStr)
        self.assertEqual(assign.value.args[0].values[0].value, r"Hello \n ")

    def test_multiline_t_string(self):
        source = '''template = t"""Hello
World {name}"""'''
        parser = PyASTParser()
        tree = parser.parse(source)

        assign = tree.body[0]
        self.assertIsInstance(assign.value, ast.Call)
        self.assertEqual(assign.value.func.id, "py2v_t_string")
        self.assertIsInstance(assign.value.args[0], ast.JoinedStr)
        self.assertEqual(assign.value.args[0].values[0].value, "Hello\nWorld ")

if __name__ == '__main__':
    unittest.main()
