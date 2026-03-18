from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.analyzer import TypeInference
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

def test_string_strip():
    assert translate_expr("s.strip()") == "s.trim_space()"
    assert translate_expr("s.strip('abc')") == "s.trim('abc')"

def test_string_lstrip():
    assert translate_expr("s.lstrip()") == "s.trim_left(' \\n\\r\\t\\v\\f')"
    assert translate_expr("s.lstrip('abc')") == "s.trim_left('abc')"

def test_string_rstrip():
    assert translate_expr("s.rstrip()") == "s.trim_right(' \\n\\r\\t\\v\\f')"
    assert translate_expr("s.rstrip('abc')") == "s.trim_right('abc')"

def test_string_case():
    assert translate_expr("s.lower()") == "s.to_lower()"
    assert translate_expr("s.upper()") == "s.to_upper()"
    assert translate_expr("s.capitalize()") == "s.capitalize()"
    assert translate_expr("s.title()") == "s.title()"

def test_string_search():
    assert translate_expr("s.find('x')") == "s.index('x') or { -1 }"
    assert translate_expr("s.index('x')") == "s.index('x') or { panic('ValueError: substring not found') }"

def test_string_replace():
    assert translate_expr("s.replace('a', 'b')") == "s.replace('a', 'b')"
    assert translate_expr("s.replace('a', 'b', 1)") == "s.replace_n('a', 'b', 1)"

def test_string_split():
    assert translate_expr("s.split()") == "s.fields()"
    assert translate_expr("s.split(',')") == "s.split(',')"
    assert translate_expr("s.split(',', 1)") == "s.split_nth(',', 1 + 1)"

def test_string_format():
    assert translate_expr("s.format(a, b)") == "/* s.format(...) */ s //##LLM@@ .format() is not supported, use interpolation"
