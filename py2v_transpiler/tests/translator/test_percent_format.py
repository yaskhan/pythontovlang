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
        self.used_string_format = False

    def _indent(self):
        return "    " * self._indent_level

    def _mangle_name(self, name, class_name):
        return name

    def visit(self, node):
        return super().visit(node)

    def _guess_type(self, node):
         return "string"

    def visit_Name(self, node: ast.Name):
        return node.id

def translate_expr(expr_str):
    tree = ast.parse(expr_str).body[0].value
    emitter = MockEmitter()
    analyzer = TypeInference()
    analyzer.analyze(ast.parse(expr_str))
    translator = TestTranslator(emitter=emitter, type_inference=analyzer)
    res = translator.visit(tree)
    return res, translator.used_string_format

def test_string_format_percent_simple():
    res, used = translate_expr("'Hello %s' % 'World'")
    assert "`Hello ${'World'}`" in res
    assert used

def test_string_format_percent_number():
    res, used = translate_expr("'Num %d' % 123")
    assert "`Num ${123}`" in res
    assert used

def test_string_format_percent_float():
    res, used = translate_expr("'%.2f' % 3.14")
    assert "py_string_format('%.2f', 3.14)" in res
    assert used

def test_string_format_percent_tuple():
    res, used = translate_expr("'%s %d' % ('Age', 30)")
    # Tuple args should be flattened
    assert "`${'Age'} ${30}`" in res
    assert used

def test_integer_modulo():
    # 10 % 3 -> 10 % 3, not format
    # guess type 10 -> int
    # 10 is int, 3 is int.
    # visit_BinOp checks types.
    tree = ast.parse("10 % 3").body[0].value
    emitter = MockEmitter()
    analyzer = TypeInference()
    translator = TestTranslator(emitter=emitter, type_inference=analyzer)
    # Mock guess_type to return int for 10 and 3
    def mock_guess_type(node):
        return "int"
    translator._guess_type = mock_guess_type

    res = translator.visit(tree)
    assert res == "10 % 3"
    assert not translator.used_string_format
