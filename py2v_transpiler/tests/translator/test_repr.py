import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

class DummyTranslator(VNodeVisitor):
    def __init__(self):
        super().__init__(TypeInference())
        self._scope_stack = [set()]
        
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

    assert "fn (self MyClass) str() string {" in generated_code
    assert "fn (self MyClass) repr() string {" in generated_code

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

    assert "fn (self MyClass2) str() string {" in generated_code
