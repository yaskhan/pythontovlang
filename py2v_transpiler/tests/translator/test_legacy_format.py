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
    return translator.visit_Module(tree)

def test_string_percent_format_single():
    source = """
name = "World"
greeting = "Hello %s" % name
"""
    v_code = translate(source)
    assert "sprintf" in v_code
    assert "greeting :=" in v_code

def test_string_percent_format_multiple():
    source = """
name = "World"
count = 42
msg = "Hello %s, count: %d" % (name, count)
"""
    v_code = translate(source)
    assert "sprintf" in v_code
    assert "msg :=" in v_code

def test_string_percent_format_int():
    source = """
num = 42
s = "Number: %d" % num
"""
    v_code = translate(source)
    assert "sprintf" in v_code

def test_string_percent_format_float():
    source = """
val = 3.14
s = "Value: %f" % val
"""
    v_code = translate(source)
    assert "sprintf" in v_code
