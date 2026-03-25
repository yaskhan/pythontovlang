import textwrap
import unittest
from typing import cast
import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def transpile(source_code: str) -> str:
    parser = PyASTParser()
    analyzer = TypeInference()
    tree = parser.parse(source_code)
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    translator.visit_Module(cast(ast.Module, tree))
    return translator.emitter.emit()

class TestTypedCollections(unittest.TestCase):
    def test_homogeneous_list_int(self):
        code = "l = [1, 2, 3]"
        v_code = transpile(code)
        # V supports literal inference for simple lists
        assert "l := [1, 2, 3]" in v_code

    def test_homogeneous_list_str(self):
        code = "l = ['a', 'b']"
        v_code = transpile(code)
        assert "l := ['a', 'b']" in v_code

    def test_mixed_list(self):
        code = "l = [1, 'a']"
        v_code = transpile(code)
        assert "l := [1, 'a']" in v_code

    def test_homogeneous_dict_str_int(self):
        code = "d = {'a': 1, 'b': 2}"
        v_code = transpile(code)
        assert "d := {'a': 1, 'b': 2}" in v_code

    def test_homogeneous_dict_int_str(self):
        code = "d = {1: 'a', 2: 'b'}"
        v_code = transpile(code)
        assert "d := {1: 'a', 2: 'b'}" in v_code

    def test_empty_list_with_annotation(self):
        code = "l: list[int] = []"
        v_code = transpile(code)
        # Explicit annotation forces typed literal
        assert "l := []int{}" in v_code

    def test_empty_dict_with_annotation(self):
        code = "d: dict[str, int] = {}"
        v_code = transpile(code)
        assert "d := map[string]int{}" in v_code

    def test_list_append_inference(self):
        code = """
items = []
items.append(1)
"""
        v_code = transpile(textwrap.dedent(code).strip())
        # items = [] is untyped, but append(1) should ideally trigger []int
        # However, currently it might just be []int{} or []Any{}
        assert "items := []int{}" in v_code

if __name__ == "__main__":
    unittest.main()
