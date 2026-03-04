import pytest
import ast
from py2v_transpiler.core.compatibility import CompatibilityLayer
from py2v_transpiler.core.parser import PyASTParser

def test_preprocess_bracketless_except():
    comp = CompatibilityLayer()
    source = """
try:
    x = 1 / 0
except ValueError, ZeroDivisionError as e:
    print(e)
"""
    expected = """
try:
    x = 1 / 0
except (ValueError, ZeroDivisionError) as e:
    print(e)
"""
    # The actual implementation might have different whitespace but the AST should be the same
    processed, _ = comp.preprocess_source(source)
    assert "(ValueError, ZeroDivisionError) as e:" in processed

def test_preprocess_bracketless_except_star():
    comp = CompatibilityLayer()
    source = """
try:
    ...
except* ValueError, TypeError:
    pass
"""
    processed, _ = comp.preprocess_source(source)
    assert "except* (ValueError, TypeError):" in processed

def test_is_v_reserved():
    comp = CompatibilityLayer()
    assert comp.is_v_reserved("fn") is True
    assert comp.is_v_reserved("mut") is True
    assert comp.is_v_reserved("my_var") is False

def test_is_python_soft_keyword():
    comp = CompatibilityLayer()
    assert comp.is_python_soft_keyword("match") is True
    assert comp.is_python_soft_keyword("case") is True
    assert comp.is_python_soft_keyword("x") is False

def test_parser_integration():
    parser = PyASTParser()
    # This syntax would normally fail on Python < 3.14 without pre-processing
    source = """
try:
    pass
except ValueError, TypeError:
    pass
"""
    # If it parses without error, our pre-processor worked
    tree = parser.parse(source)
    assert isinstance(tree, ast.Module)
    # Verify the AST has a tuple for the exception types
    try_node = tree.body[0]
    assert isinstance(try_node, ast.Try)
    handler = try_node.handlers[0]
    assert isinstance(handler.type, ast.Tuple)
