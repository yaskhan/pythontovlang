import ast
from py2v_transpiler.core.translator.expressions_split.calls import CallsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v

class DummyEmitter:
    def __init__(self):
        self.imports = set()
    def add_import(self, imp):
        self.imports.add(imp)

class DummyMapper:
    def get_mapping(self, mod, func, args):
        return None

class DummyTypeInference:
    call_signatures = {}

class DummyCoroutineHandler:
    def is_generator(self, name):
        return False

class TestTranslator(CallsMixin, LiteralsMixin, TranslatorBase):
    def __init__(self):
        super().__init__(type_inference=DummyTypeInference())
        self.emitter = DummyEmitter()
        self.mapper = DummyMapper()
        self.type_inference = DummyTypeInference()
        self.coroutine_handler = DummyCoroutineHandler()
        self.imported_modules = {"six": "six"}
        self.imported_symbols = {"u": "six.u", "text_type": "six.text_type"}

def test_six_u():
    trans = TestTranslator()
    node = ast.parse("six.u('abc')").body[0].value
    res = trans.visit_Call(node)
    assert res == "'abc'"

    node2 = ast.parse("u('abc')").body[0].value
    res2 = trans.visit_Call(node2)
    assert res2 == "'abc'"

def test_six_text_type():
    trans = TestTranslator()
    node = ast.parse("six.text_type(123)").body[0].value
    res = trans.visit_Call(node)
    assert res == "123.str()"

    node2 = ast.parse("text_type(123)").body[0].value
    res2 = trans.visit_Call(node2)
    assert res2 == "123.str()"
