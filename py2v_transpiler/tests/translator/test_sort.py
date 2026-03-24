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
         return "int"

    def visit_Name(self, node: ast.Name):
        return node.id

def translate_expr(expr_str):
    tree = ast.parse(expr_str).body[0].value
    emitter = MockEmitter()
    analyzer = TypeInference()
    analyzer.analyze(ast.parse(expr_str))
    translator = TestTranslator(emitter=emitter, type_inference=analyzer)
    return translator.visit(tree)

def test_sort_reverse_true():
    # l.sort(reverse=True) -> l.sort(a > b)
    assert translate_expr("l.sort(reverse=True)") == "l.sort(a > b)"

def test_sort_reverse_false():
    # l.sort(reverse=False) -> l.sort()
    assert translate_expr("l.sort(reverse=False)") == "l.sort()"

def test_sort_no_args():
    # l.sort() -> l.sort()
    assert translate_expr("l.sort()") == "l.sort()"

def test_sort_key_len():
    # words.sort(key=len) -> words.sort(a.len < b.len)
    assert translate_expr("words.sort(key=len)") == "words.sort(a.len < b.len)"

def test_sort_key_len_reverse():
    # words.sort(key=len, reverse=True) -> words.sort(a.len > b.len)
    assert translate_expr("words.sort(key=len, reverse=True)") == "words.sort(a.len > b.len)"

def test_sort_key_str():
    # nums.sort(key=str) -> nums.sort(a.str() < b.str())
    assert translate_expr("nums.sort(key=str)") == "nums.sort(a.str() < b.str())"

def test_sort_key_int():
    # nums.sort(key=int) -> nums.sort(int(a) < int(b))
    assert translate_expr("nums.sort(key=int)") == "nums.sort(int(a) < int(b))"

def test_sort_key_unknown():
    # l.sort(key=my_func) -> l.sort(my_func(a) < my_func(b))
    assert translate_expr("l.sort(key=my_func)") == "l.sort(my_func(a) < my_func(b))"

def test_sort_key_unknown_reverse():
    # l.sort(key=my_func, reverse=True) -> l.sort(my_func(a) > my_func(b))
    assert translate_expr("l.sort(key=my_func, reverse=True)") == "l.sort(my_func(a) > my_func(b))"

def test_sort_reverse_keyword_dynamic():
    # l.sort(reverse=x) -> l.sort() (only constant True supported)
    # If dynamic reverse is passed, we currently fallback to default sort()
    # Or should we generate runtime check? Current implementation only checks Constant(True).
    assert translate_expr("l.sort(reverse=x)") == "l.sort()"
