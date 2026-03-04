import unittest
import sys
import ast
from py2v_transpiler.main import Transpiler
from py2v_transpiler.core.parser import PyASTParser

class TestPEP696(unittest.TestCase):
    def setUp(self):
        self.transpiler = Transpiler()
        self.parser = PyASTParser()

    def test_class_default(self):
        source = "class Box[T = int]: pass\nb: Box"
        v_code = self.transpiler.transpile(source)
        self.assertIn("struct Box[T] {", v_code)
        self.assertIn("mut b := Box[int]{}", v_code)

    def test_function_default(self):
        source = "def foo[T = str](x: T): pass"
        v_code = self.transpiler.transpile(source)
        self.assertIn("fn foo[T](x T) {", v_code)

    def test_type_alias_default(self):
        source = "type MyList[T = int] = list[T]\nl: MyList"
        v_code = self.transpiler.transpile(source)
        self.assertIn("type MyList[T] = []T", v_code)
        self.assertIn("mut l := MyList[int]{}", v_code)

    def test_multiple_defaults(self):
        source = "class Map[K = str, V = int]: pass\nm: Map[int]"
        v_code = self.transpiler.transpile(source)
        self.assertIn("struct Map[K, V] {", v_code)
        self.assertIn("mut m := Map[int, int]{}", v_code)

if __name__ == "__main__":
    unittest.main()
