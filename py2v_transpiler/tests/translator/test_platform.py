import ast
import pytest
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

def test_platform_system():
    source = """
import platform
s = platform.system()
"""
    v_code = translate(source)
    assert "os.user_os()" in v_code

def test_platform_machine():
    source = """
import platform
m = platform.machine()
"""
    v_code = translate(source)
    assert "py_platform_machine()" in v_code
