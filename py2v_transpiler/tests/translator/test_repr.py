import ast
from py2v_transpiler.core.translator.classes import ClassesMixin
from py2v_transpiler.core.translator.functions import FunctionsMixin
from py2v_transpiler.core.translator.variables import VariablesMixin
from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler
from unittest.mock import MagicMock

class DummyTranslator(ClassesMixin, FunctionsMixin, VariablesMixin, ExpressionsMixin, LiteralsMixin, TranslatorBase):
    def __init__(self):
        super().__init__(type_inference=MagicMock())
        self.emitter = VCodeEmitter()
        self.decorator_processor = DecoratorProcessor(self.emitter)
        self.coroutine_handler = CoroutineHandler()
        self.output = []
        self._indent_level = 0
        self.current_class = None
        self.class_hierarchy = {}
        self.known_interfaces = set()

def test_repr_and_str_rename():
    code = """
class MyClass:
    def __str__(self):
        return "str"
    def __repr__(self):
        return "repr"
"""
    tree = ast.parse(code)
    translator = DummyTranslator()
    translator.visit(tree)

    generated_code = translator.emitter.emit()

    assert "fn (self MyClass) str() {" in generated_code
    assert "fn (self MyClass) repr() {" in generated_code

def test_repr_without_str():
    code = """
class MyClass2:
    def __repr__(self):
        return "repr"
"""
    tree = ast.parse(code)
    translator = DummyTranslator()
    translator.visit(tree)

    generated_code = translator.emitter.emit()

    assert "fn (self MyClass2) str() {" in generated_code
    assert "fn (self MyClass2) repr() {" not in generated_code
