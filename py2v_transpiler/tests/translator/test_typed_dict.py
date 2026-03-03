import ast
from py2v_transpiler.core.translator.classes import ClassesMixin
from py2v_transpiler.core.translator.variables_split import VariablesMixin
from py2v_transpiler.core.translator.functions import FunctionsMixin
from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.core.coroutines import CoroutineHandler
from unittest.mock import MagicMock

class MockTypeInference:
    def __init__(self):
        self.type_map = {}
        self.location_map = {}

    def resolve_type(self, node):
        if isinstance(node, ast.Name):
            return self.type_map.get(node.id, "void")
        return "void"

from py2v_transpiler.core.translator.base import TranslatorBase

class _TestTranslator(ClassesMixin, VariablesMixin, FunctionsMixin, ExpressionsMixin, LiteralsMixin, TranslatorBase):
    def __init__(self):
        super().__init__(type_inference=MockTypeInference())
        self.output = []
        self.emitter = VCodeEmitter()
        self.coroutine_handler = CoroutineHandler()
        self._indent_level = 0
        self.current_class = None
        self.current_class_generics = []
        self.current_class_bases = []
        self.current_class_is_unittest = False
        self.imported_modules = {}
        self.imported_symbols = {}
        self.renamed_functions = {}
        self.function_names = set()
        self.used_builtins = set()
        self.unique_id_counter = 0
        self.name_remap = {}
        self._walrus_assignments = []
        self._zip_counter = 0
        self.in_main = False
        self.single_dispatch_functions = {}
        self.vexc_depth = 0
        self.type_inference = MockTypeInference()

        # Mocking
        self.decorator_processor = MagicMock()
        self.decorator_processor.analyze.return_value = MagicMock(
            is_static=False, is_setter=False,
            cache_wrapper_needed=False, implementation_name=None,
            injected_start=[], injected_end=[]
        )
        self.mapper = MagicMock()
        self.mapper.get_mapping.return_value = None
        self.mapper.get_constant_mapping.return_value = None
        self.dataclasses = {}

    def _indent(self):
        return "    " * self._indent_level

    def visit(self, node):
        method = 'visit_' + node.__class__.__name__
        visitor = getattr(self, method, self.generic_visit)
        return visitor(node)

    def generic_visit(self, node):
        if hasattr(node, "body"):
            for stmt in node.body:
                self.visit(stmt)
        return ""

    def _guess_type(self, node):
        if isinstance(node, ast.Name):
            return self.type_inference.type_map.get(node.id, "int")
        return "int"

    def _mangle_name(self, name, class_name):
        return name

def test_typed_dict():
    code = """
from typing import TypedDict

class MyDict(TypedDict):
    a: int
    b: str

class MyDict2(TypedDict, total=False):
    a: int
    b: str

d: MyDict = {"a": 1, "b": "hello"}
d["a"] = 2
d["b"] = "world"
print(d["a"])
"""
    tree = ast.parse(code)
    translator = _TestTranslator()

    # Simulate mypy inferring type as TypedDict struct
    translator.type_inference.type_map["d"] = "MyDict"

    translator.visit(tree)

    structs = translator.emitter.structs
    assert any("struct MyDict {" in s for s in structs)

    v_code = "\n".join(translator.output)
    print("V_CODE:")
    print(v_code)

    assert "d := MyDict{a: 1, b: 'hello'}" in v_code
    assert "d.a = 2" in v_code
    assert "d.b = 'world'" in v_code
    assert "d.a" in v_code

def test_typed_dict_readonly():
    code = """
from typing import TypedDict, ReadOnly

class MyDict(TypedDict):
    a: int
    b: ReadOnly[str]

d: MyDict = {"a": 1, "b": "hello"}
d["a"] = 2
d["b"] = "world"
"""
    tree = ast.parse(code)
    translator = _TestTranslator()

    # Simulate mypy inferring type as TypedDict struct
    translator.type_inference.type_map["d"] = "MyDict"

    translator.visit(tree)

    structs = translator.emitter.structs
    assert any("struct MyDict {" in s for s in structs)

    # Check that ReadOnly[str] is mapped to string
    struct_code = next(s for s in structs if "struct MyDict" in s)
    assert "b string" in struct_code

    v_code = "\n".join(translator.output)
    print("V_CODE:")
    print(v_code)

    assert "d := MyDict{a: 1, b: 'hello'}" in v_code
    assert "d.a = 2" in v_code
    assert "$compile_error('Cannot assign to ReadOnly TypedDict field \\'b\\'')" in v_code
