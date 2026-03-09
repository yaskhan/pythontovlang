import ast
import os
import sys

# Add the project root to sys.path to import py2v_transpiler
sys.path.insert(0, os.getcwd())

from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.expressions_split.comprehensions import ComprehensionsMixin
from py2v_transpiler.core.parser import PyASTParser

class MockTranslator(LiteralsMixin, ComprehensionsMixin):
    def __init__(self):
        self.current_assignment_type = None
        self.parent_stack = []
        self._literal_enum_values = {}
        self.used_complex = False
        self.used_list_concat = False
        self.used_builtins = set()
        self.output = []
        self._indent_level = 0
        self.type_inference = type('MockTypeInference', (), {'type_map': {}, 'resolve_type': lambda self, x: "Any"})()
        self.unique_id_counter = 0
        self._zip_counter = 0
        self.name_remap = {}

    def visit(self, node):
        if node is None: return "none"
        method = 'visit_' + node.__class__.__name__
        visitor = getattr(self, method, self.generic_visit)
        return visitor(node)

    def generic_visit(self, node):
        return f"GENERIC_{node.__class__.__name__}"

    def visit_Name(self, node):
        return node.id

    def _guess_type(self, node):
        if isinstance(node, ast.List):
            if not node.elts:
                return "[]Any"
            return "[]int" # simplified
        if isinstance(node, ast.Constant):
            if isinstance(node.value, int): return "int"
            if isinstance(node.value, str): return "string"
        return "Any"

    def _indent(self):
        return "    " * self._indent_level

    def _infer_generator_types(self, gen):
        pass

    def _is_exported(self, name):
        return False

    def _to_snake_case(self, name):
        return name

def test_list_literal():
    translator = MockTranslator()

    print("--- List Literals ---")
    # Test 1: Simple list literal
    code = "[1, 2, 3]"
    node = ast.parse(code).body[0].value
    result = translator.visit(node)
    print(f"Python: {code} -> V: {result}")

    # Test 2: Empty list
    code = "[]"
    node = ast.parse(code).body[0].value
    result = translator.visit(node)
    print(f"Python: {code} -> V: {result}")

    # Test 3: Typed list (simulated)
    translator.current_assignment_type = "[]int"
    code = "[1, 2, 3]"
    node = ast.parse(code).body[0].value
    result = translator.visit(node)
    print(f"Python (typed []int): {code} -> V: {result}")

def test_comprehension():
    translator = MockTranslator()
    print("\n--- List Comprehensions ---")
    code = "[i for i in range(10)]"
    node = ast.parse(code).body[0].value
    translator.output = []
    result_var = translator.visit(node)
    print(f"Python: {code}")
    print("V Output:")
    print("\n".join(translator.output))
    print(f"Result expression: {result_var}")

if __name__ == "__main__":
    test_list_literal()
    test_comprehension()
