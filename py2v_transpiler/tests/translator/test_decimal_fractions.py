import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_fractions_fraction():
    source = """
import fractions
f = fractions.Fraction(1, 2)
g = fractions.Fraction('0.5')
"""
    v_code = translate(source)
    assert "import math.fractions" in v_code
    # Expected V mapping: fractions.fraction(n, d)
    assert "f := fractions.fraction(1, 2)" in v_code
    # String init? V fractions.fraction(n, d).
    # fractions.from_f64(0.5) is available?
    # Or helper py_fraction.
    assert "g := py_fraction('0.5')" in v_code
