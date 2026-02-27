from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.generator import VCodeEmitter
import ast

class MockEmitter:
    def __init__(self):
        self.imports = set()
    def add_import(self, module):
        self.imports.add(module)

class TestTranslator(ExpressionsMixin, LiteralsMixin):
    def __init__(self, emitter, type_inference):
        self.output = []
        self.emitter = emitter
        self.type_inference = type_inference
        self.imported_modules = {}
        self.imported_symbols = {}
        self.renamed_functions = {}
        self.used_builtins = set()
        self.function_names = set()
        self.current_class = None
        self.current_class_bases = []
        self.mapper = None
        self._indent_level = 0
        self.coroutine_handler = None
        self.loop_stack = []
        self.name_remap = {}

    def _indent(self):
        return "    " * self._indent_level

    def _mangle_name(self, name, class_name):
        return name

    def visit(self, node):
        return super().visit(node)

    def _guess_type(self, node):
         if isinstance(node, ast.Constant):
             if isinstance(node.value, int): return "int"
             if isinstance(node.value, float): return "f64"
         return "int" # Default to int for this test

    def visit_Name(self, node: ast.Name):
        return node.id

def translate_expr(expr_str):
    tree = ast.parse(expr_str).body[0].value
    emitter = MockEmitter()
    analyzer = TypeInference()
    analyzer.analyze(ast.parse(expr_str))
    translator = TestTranslator(emitter=emitter, type_inference=analyzer)
    return translator.visit(tree)

def test_floor_div_int():
    # -7 // 2 -> int(math.floor(f64(-7) / f64(2)))
    assert translate_expr("-7 // 2") == "int(math.floor(f64(-7) / f64(2)))"
    # 7 // -2 -> int(math.floor(f64(7) / f64(-2)))
    assert translate_expr("7 // -2") == "int(math.floor(f64(7) / f64(-2)))"

def test_floor_div_float():
    # 7.0 // 2 -> math.floor(7.0 / 2)
    # _guess_type logic in test harness is simple, but we can mock it per call if needed.
    # Here, left is float, right is int.
    # _guess_type in expressions.py checks operands recursively.
    # In test harness, Constant(7.0) returns "f64".
    assert translate_expr("7.0 // 2") == "math.floor(7.0 / 2)"
    assert translate_expr("7 // 2.0") == "math.floor(7 / 2.0)"
