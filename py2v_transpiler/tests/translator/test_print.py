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

def test_print_basic():
    source = "print('Hello')"
    v_code = translate(source)
    assert "println('Hello')" in v_code

def test_print_multiple_args():
    source = "print('A', 'B')"
    v_code = translate(source)
    assert "println('A B')" in v_code

def test_print_sep():
    source = "print('A', 'B', sep='-')"
    v_code = translate(source)
    assert "println('A-B')" in v_code

def test_print_end_empty():
    source = "print('A', end='')"
    v_code = translate(source)
    assert "print('A')" in v_code

def test_print_end_custom():
    source = "print('A', end='!')"
    v_code = translate(source)
    assert "print('A!')" in v_code

def test_print_vars():
    source = """
x = 1
y = 2
print(x, y, sep=', ')
"""
    v_code = translate(source)
    # x and y are vars, so ${x} and ${y}
    assert "println('${x}, ${y}')" in v_code

def test_print_stderr():
    source = """
import sys
print('Error', file=sys.stderr)
print('Error', file=sys.stderr, end='')
print('Error', file=sys.stderr, end='!')
"""
    v_code = translate(source)
    assert "eprintln('Error')" in v_code
    assert "eprint('Error')" in v_code
    assert "eprint('Error!')" in v_code
