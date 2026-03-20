import ast
from py2v_transpiler.core.translator.expressions_split.calls import CallsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.variables_split.names import NamesMixin

class MockTypeInference:
    def __init__(self):
        self.type_map = {}
        self.static_methods = {}
        self.class_methods = {}
    def resolve_type(self, node):
        return "void"

class MockTranslator(CallsMixin, LiteralsMixin, NamesMixin, TranslatorBase):
    def __init__(self):
        super().__init__(type_inference=MockTypeInference())
        self.imported_modules = {}
        self.imported_symbols = {}
        self.used_builtins = set()
        self.emitter = type('MockEmitter', (), {'add_import': lambda self, x: None})()
        self.coroutine_handler = type('MockCoroutineHandler', (), {'is_generator': lambda self, x: False})()
        self.mapper = type('MockMapper', (), {'get_mapping': lambda self, mod, func, args: None})()
        self.overloaded_signatures = {}
        self.scc_files = []
        self.current_class_bases = []
        self.name_remap = {}
        self.current_class = None
        self.defined_classes = {}
        self.renamed_functions = {"main": "py_main"}
        self._scope_stack = [set()]

    def visit(self, node):
        if node is None: return "none"
        method = 'visit_' + node.__class__.__name__
        visitor = getattr(self, method, self.generic_visit)
        return visitor(node)

    def generic_visit(self, node):
        return f"/* unknown: {type(node).__name__} */"

def translate_expr(expr_code, type_map=None):
    tree = ast.parse(expr_code)
    translator = MockTranslator()
    if type_map:
        translator.type_inference.type_map.update(type_map)
    return translator.visit(tree.body[0].value)

def test_bytes_translation():
    assert translate_expr("bytes()") == "[]u8{}"
    assert translate_expr("bytes(10)") == "[]u8{len: 10}"
    assert translate_expr("bytes([1, 2, 3])") == "[1, 2, 3].clone()"
    assert translate_expr("bytes('abc', 'utf-8')") == "'abc'.bytes()"

def test_bytearray_translation():
    assert translate_expr("bytearray()") == "[]u8{}"
    assert translate_expr("bytearray(5)") == "[]u8{len: 5}"
    assert translate_expr("bytearray([1, 2, 3])") == "[1, 2, 3].clone()"
    assert translate_expr("bytearray(b'abc')") == "[u8(0x61), u8(0x62), u8(0x63)].clone()"
    assert translate_expr("bytearray('abc', 'utf-8')") == "'abc'.bytes()"

def test_memoryview_translation():
    assert translate_expr("memoryview(b'abc')") == "[u8(0x61), u8(0x62), u8(0x63)]"
    assert translate_expr("memoryview(x)", {"x": "[]u8"}) == "x"

if __name__ == "__main__":
    test_bytes_translation()
    test_bytearray_translation()
    test_memoryview_translation()
    print("All buffer protocol translation tests passed!")
