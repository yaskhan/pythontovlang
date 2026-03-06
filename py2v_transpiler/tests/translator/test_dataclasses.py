import ast
from py2v_transpiler.core.translator.classes import ClassesMixin
from py2v_transpiler.core.translator.functions import FunctionsMixin
from py2v_transpiler.core.translator.variables_split import VariablesMixin
from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.core.analyzer import TypeInference

class DummyTranslator(ClassesMixin, FunctionsMixin, VariablesMixin, ExpressionsMixin, LiteralsMixin, TranslatorBase):
    pass

def test_perfect_field_inference():
    code = """
import dataclasses
from typing import ClassVar, InitVar

@dataclasses.dataclass
class Point:
    x: int
    y: int = 5
    z: InitVar[int] = 0
    c: ClassVar[int] = 10

p = Point(1, z=3)
"""

    translator = DummyTranslator(TypeInference())
    translator.emitter = VCodeEmitter()
    translator.type_inference.call_signatures = {
        "Point@11:4": {
            "dataclass_metadata": {
                "attributes": [
                    {"name": "x", "is_in_init": True, "is_init_var": False, "has_default": False, "type": "builtins.int"},
                    {"name": "y", "is_in_init": True, "is_init_var": False, "has_default": True, "type": "builtins.int"},
                    {"name": "z", "is_in_init": True, "is_init_var": True, "has_default": True, "type": "builtins.int"}
                ]
            }
        },
        "Point@12:4": {
            "dataclass_metadata": {
                "attributes": [
                    {"name": "x", "is_in_init": True, "is_init_var": False, "has_default": False, "type": "builtins.int"},
                    {"name": "y", "is_in_init": True, "is_init_var": False, "has_default": True, "type": "builtins.int"},
                    {"name": "z", "is_in_init": True, "is_init_var": True, "has_default": True, "type": "builtins.int"}
                ]
            }
        }
    }

    tree = ast.parse(code)
    translator.visit(tree)
    out = translator.emitter.emit()
    print("OUTPUT:\n", out)

    assert "struct Point {" in out
    assert "x int" in out
    assert "y int = 5" in out
    assert "z int" not in out # InitVar shouldn't be a field
    assert "c int" not in out # ClassVar shouldn't be a field (though we didn't add it explicitly to attributes above so it's ignored)

    # We passed z as kwarg - InitVar should be excluded from struct init if not using factory
    # The translator outputs 'p := Point{x: 1}' to self.output
    output_str = "".join(translator.output)
    assert "Point{x: 1}" in out or "Point{x: 1}" in output_str

    # Actually visit_Assign outputs to translator.output or emitter?
    # VariablesMixin adds to translator.output. But in DummyTranslator we don't handle Module level assignments to put them in a function.
    # We can check translator.output
    print("Translator output:", translator.output)
