import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_generator_helpers_emitted():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def my_gen():
    yield 1
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    translator.visit_Module(tree)

    helpers = translator.emitter.emit_helpers()

    assert "pub struct PyGeneratorInput" in helpers
    assert "pub struct PyGenerator[T]" in helpers
    assert "pub fn (mut g PyGenerator[T]) next() ?T" in helpers
    assert "pub fn py_yield[T]" in helpers

def test_generator_helpers_not_emitted_when_not_used():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def my_func():
    return 1
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    translator.visit_Module(tree)

    helpers = translator.emitter.emit_helpers()

    assert "PyGenerator" not in helpers
    assert "py_yield" not in helpers

def test_any_definition_present():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    tree = parser.parse("pass")
    analyzer.analyze(tree)
    translator.visit_Module(tree)

    helpers = translator.emitter.emit_helpers()
    assert "pub type Any = bool | int | i64 | f64 | string | []u8 | none" in helpers
