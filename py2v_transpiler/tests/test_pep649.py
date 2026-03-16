import unittest
import sys
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile_code(source_code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source_code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

class TestPEP649(unittest.TestCase):
    def test_get_type_hints_deferred(self):
        code = """
from typing import get_type_hints

class Foo:
    x: 'Bar'

class Bar:
    y: int

def main():
    hints = get_type_hints(Foo)
    print(hints)
"""
        v_code = transpile_code(code)
        # We expect get_type_hints(Foo) to be mapped to something that works in V
        # e.g., py_get_type_hints[Foo]()
        self.assertIn("py_get_type_hints[Foo]()", v_code)

    def test_annotationlib_get_annotations(self):
        # Even if annotationlib is only in 3.14, the transpiler should map it if it sees it.
        code = """
import annotationlib

class Foo:
    x: int

def main():
    annos = annotationlib.get_annotations(Foo)
    print(annos)
"""
        v_code = transpile_code(code)
        self.assertIn("py_get_type_hints[Foo]()", v_code)

    def test_annotations_attribute(self):
        code = """
class Foo:
    x: int

def main():
    print(Foo.__annotations__)
"""
        v_code = transpile_code(code)
        self.assertIn("py_get_type_hints[Foo]()", v_code)

    def test_function_annotations_deferred(self):
        code = """
from typing import get_type_hints

def func(x: 'Bar') -> 'Bar':
    return x

class Bar:
    pass

def main():
    print(get_type_hints(func))
"""
        v_code = transpile_code(code)
        # For functions, we might need a different approach as V doesn't have reflection for function params as easily
        # or we generate a metadata constant.
        self.assertIn("func__annotations__", v_code)

if __name__ == "__main__":
    unittest.main()
