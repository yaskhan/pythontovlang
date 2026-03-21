"""Tests for **kwargs call unpacking (Issue #27)."""

import unittest
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


class TestKwargsCallUnpacking(unittest.TestCase):

    def test_dict_literal_unpacking_known_signature(self):
        """func(**{"a": 1, "b": 2}) with known signature emits func(1, 2)."""
        code = """
def func(a: int, b: int) -> int:
    return a + b

result = func(**{"a": 1, "b": 2})
"""
        v_code = transpile_code(code)
        self.assertIn("func(1, 2)", v_code)

    def test_variable_name_unpacking_known_signature(self):
        """func(**kwargs) with known signature emits subscript accesses per arg."""
        code = """
def func(a: int, b: int, c: int) -> int:
    return a + b + c

kwargs = {"a": 1, "b": 2, "c": 3}
result = func(**kwargs)
"""
        v_code = transpile_code(code)
        self.assertIn("kwargs['a']", v_code)
        self.assertIn("kwargs['b']", v_code)
        self.assertIn("kwargs['c']", v_code)

    def test_has_kwarg_passthrough(self):
        """When callee has **kwargs parameter, the map is passed directly."""
        code = """
def func(**kwargs) -> None:
    pass

func(**{"a": 1, "b": 2})
"""
        v_code = transpile_code(code)
        self.assertNotIn("//##LLM@@", v_code)
        self.assertIn("'a': 1", v_code)
        self.assertIn("'b': 2", v_code)

    def test_unknown_signature_fallback(self):
        """Unknown signature passes dict as-is and emits //##LLM@@ warning comment."""
        code = """
from some_external_module import external_func

d = {"x": 1}
external_func(**d)
"""
        v_code = transpile_code(code)
        self.assertIn("//##LLM@@", v_code)
        self.assertIn("d", v_code)

    def test_dict_literal_partial_match(self):
        """Only args present in the dict are filled; no crash for missing keys."""
        code = """
def func(a: int, b: int) -> int:
    return a + b

result = func(**{"a": 42})
"""
        v_code = transpile_code(code)
        self.assertIn("42", v_code)
        self.assertNotIn("//##LLM@@", v_code)

    def test_variable_name_unpacking_preserves_order(self):
        """Subscript accesses are emitted in signature order, not dict insertion order."""
        code = """
def func(x: int, y: int) -> int:
    return x + y

params = {"y": 2, "x": 1}
result = func(**params)
"""
        v_code = transpile_code(code)
        idx_x = v_code.find("params['x']")
        idx_y = v_code.find("params['y']")
        self.assertGreater(idx_x, -1)
        self.assertGreater(idx_y, -1)
        self.assertLess(idx_x, idx_y)

    def test_dict_literal_dynamic_key_fallback(self):
        """Dict with dynamic (non-constant-string) key falls back to dict-as-is + LLM comment."""
        code = """
def func(a: int, b: int) -> int:
    return a + b

k = "a"
result = func(**{k: 1, "b": 2})
"""
        v_code = transpile_code(code)
        self.assertIn("//##LLM@@", v_code)

    def test_nested_call_llm_comment_isolation(self):
        """Nested unresolvable **d emits //##LLM@@ as standalone comment, not inline."""
        code = """
def outer(x: int) -> int:
    return x

from some_external_module import unresolvable

d = {"x": 1}
result = outer(unresolvable(**d))
"""
        v_code = transpile_code(code)
        self.assertIn("//##LLM@@", v_code)
        # The LLM comment must be a standalone line, never inside the argument list
        for line in v_code.splitlines():
            stripped = line.strip()
            if "outer(" in stripped:
                self.assertNotIn("//##LLM@@", stripped,
                                 "LLM comment must not appear inside the argument list of outer()")
            if "unresolvable(" in stripped:
                self.assertNotIn("//##LLM@@", stripped,
                                 "LLM comment must not appear inline inside the expression")


if __name__ == "__main__":
    unittest.main()
