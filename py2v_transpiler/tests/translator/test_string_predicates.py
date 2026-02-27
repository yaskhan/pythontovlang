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
         return "string"

    def visit_Name(self, node: ast.Name):
        return node.id

def translate_expr(expr_str):
    tree = ast.parse(expr_str).body[0].value
    emitter = MockEmitter()
    analyzer = TypeInference()
    analyzer.analyze(ast.parse(expr_str))
    translator = TestTranslator(emitter=emitter, type_inference=analyzer)
    return translator.visit(tree)

def test_string_predicates_char_level():
    assert translate_expr("s.isdigit()") == "s.bytes().all(it.is_digit())"
    assert translate_expr("s.isalpha()") == "s.bytes().all(it.is_letter())"
    assert translate_expr("s.isalnum()") == "s.bytes().all(it.is_alnum())"
    assert translate_expr("s.isspace()") == "s.bytes().all(it.is_space())"

def test_string_predicates_case_level():
    assert translate_expr("s.islower()") == "s.is_lower()"
    assert translate_expr("s.isupper()") == "s.is_upper()"
    assert translate_expr("s.istitle()") == "s.is_title()"

def test_string_predicates_literals():
    assert translate_expr("'123'.isdigit()") == "'123'.bytes().all(it.is_digit())"
    assert translate_expr("'abc'.isalpha()") == "'abc'.bytes().all(it.is_letter())"
