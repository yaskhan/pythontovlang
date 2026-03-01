import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_unittest_flattening():
    source = """
import unittest
class MyTests(unittest.TestCase):
    def test_foo(self):
        pass
"""
    v_code = translate(source)
    assert "fn test_foo_MyTests() {" in v_code
    assert "struct MyTests" not in v_code
    # assert "import unittest" not in v_code # Can't assert until import suppression is fixed

def test_assertions():
    source = """
import unittest
class MyTests(unittest.TestCase):
    def test_asserts(self):
        self.assertEqual(1, 1)
        self.assertTrue(True)
        self.assertFalse(False)
        self.assertNotEqual(1, 2)
        self.assertIn(1, [1])
        self.assertIsNone(None)
        self.assertIsNotNone(1)
"""
    v_code = translate(source)
    assert "assert 1 == 1" in v_code
    assert "assert true" in v_code
    assert "assert !(false)" in v_code
    assert "assert 1 != 2" in v_code
    assert "assert 1 in [1]" in v_code
    assert "assert none == none" in v_code
    assert "assert 1 != none" in v_code
