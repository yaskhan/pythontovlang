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

def test_decimal_construction():
    source = """
import decimal
d = decimal.Decimal('1.1')
f = decimal.Decimal(1.1)
i = decimal.Decimal(1)
"""
    v_code = translate(source)
    # Expect Decimal alias or struct
    # assert "d := decimal.Decimal('1.1')" in v_code # Raw translation
    # If mapped:
    assert "d := py_decimal('1.1')" in v_code

def test_decimal_context():
    source = """
import decimal

def calc():
    with decimal.localcontext() as ctx:
        ctx.prec = 50
        decimal.getcontext().prec = 50
        d = decimal.Decimal("3.14159")
"""
    v_code = translate(source)
    assert "ctx := py_decimal_localcontext()" in v_code
    assert "defer { ctx.close() }" in v_code
    assert "ctx.prec = 50" in v_code
    assert "py_decimal_getcontext().prec = 50" in v_code
