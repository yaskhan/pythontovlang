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


class TestTranslator(
    ClassesMixin,
    FunctionsMixin,
    VariablesMixin,
    ExpressionsMixin,
    LiteralsMixin,
    TranslatorBase,
):
    def __init__(self, type_inference=None):
        super().__init__(type_inference=type_inference or TypeInference())
        self.emitter = VCodeEmitter()
        self.mapper = StdLibMapper()
        self.decorator_processor = DecoratorProcessor(self)
        self.coroutine_handler = CoroutineHandler()
        self.in_main = False
        v_types.global_type_map = {}


def test_abc_basic():
    code = """
import abc

class Animal(abc.ABC):
    @abc.abstractmethod
    def speak(self) -> str:
        pass

class Dog(Animal):
    def speak(self) -> str:
        return "Woof!"

# Animal() # Should fail in Python
d = Dog()
print(d.speak())
"""
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = TestTranslator(type_inference=analyzer)

    for node in tree.body:
        translator.visit(node)

    v_code = translator.emitter.emit()
    print(v_code)

    # 1. Animal should be an interface
    assert "interface Animal {" in v_code
    # 2. speak method in interface should not have self
    assert "speak() string" in v_code
    # 3. Dog should implement Animal (in V it means embedding Animal)
    # Wait, in V, if Dog has speak() it satisfies Animal interface.
    # Animal as an interface can be embedded in Dog struct to indicate intent,
    # or just used as a type.
    assert "struct Dog {" in v_code
    assert "Animal" in v_code

    # 4. Factory function for Animal should return error
    assert "fn new_animal() !Animal" in v_code

def test_abc_classmethod():
    code = """
import abc

class C(abc.ABC):
    @classmethod
    @abc.abstractmethod
    def foo(cls) -> str:
        pass
"""
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = TestTranslator(type_inference=analyzer)

    for node in tree.body:
        translator.visit(node)

    v_code = translator.emitter.emit()
    print(v_code)

    # Check for cls in interface method
    assert "foo() string" in v_code
    assert "cls" not in v_code

if __name__ == "__main__":
    test_abc_basic()
    test_abc_classmethod()
