import ast
from py2v_transpiler.core.translator.classes import ClassesMixin
from py2v_transpiler.core.translator.functions import FunctionsMixin
from py2v_transpiler.core.translator.variables_split import VariablesMixin
from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.stdlib_map.mapper import StdLibMapper
from py2v_transpiler.core.decorators import DecoratorProcessor
from py2v_transpiler.core.coroutines import CoroutineHandler
from py2v_transpiler.core.analyzer import TypeInference
import py2v_transpiler.models.v_types as v_types

class TestTranslator(ClassesMixin, FunctionsMixin, VariablesMixin, ExpressionsMixin, LiteralsMixin, TranslatorBase):
    def __init__(self, type_inference=None):
        super().__init__(type_inference=type_inference or TypeInference())
        self.emitter = VCodeEmitter()
        self.mapper = StdLibMapper()
        self.decorator_processor = DecoratorProcessor(self.mapper)
        self.coroutine_handler = CoroutineHandler()
        self.in_main = False
        v_types.global_type_map = {}

def test_abc_interface():
    code = """
from abc import ABC, abstractmethod

class Constraint(ABC):
    @abstractmethod
    def satisfy(self, value: int) -> bool:
        pass

class UnaryConstraint(Constraint):
    def satisfy(self, value: int) -> bool:
        return value > 0
"""
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = TestTranslator(type_inference=analyzer)

    # Process classes
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            translator.visit_ClassDef(node)

    v_code = translator.emitter.emit()
    assert "interface Constraint {" in v_code
    assert "satisfy(value int) bool" in v_code

    # Check that UnaryConstraint does NOT have Constraint as a field
    # In V, an empty struct from Python might be emitted as `struct UnaryConstraint {\n\n}`
    # depending on trailing whitespaces. We just check it does not have `Constraint` field.
    assert "struct UnaryConstraint" in v_code

    # Find UnaryConstraint block
    lines = v_code.splitlines()
    in_unary = False
    unary_fields = []
    for line in lines:
        if line.startswith("struct UnaryConstraint"):
            in_unary = True
        elif in_unary and line.startswith("}"):
            break
        elif in_unary and not line.startswith("struct"):
            unary_fields.append(line.strip())

    assert "Constraint" not in unary_fields
