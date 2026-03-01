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
    return translator.visit_Module(tree)

def test_subprocess_run():
    source = """
import subprocess
res = subprocess.run(["ls", "-l"])
print(res.returncode)
"""
    v_code = translate(source)
    assert "py_subprocess_run" in v_code
    assert "res.returncode" in v_code # V structs use . field access too

def test_subprocess_call():
    source = """
import subprocess
ret = subprocess.call(["echo", "hello"])
"""
    v_code = translate(source)
    assert "py_subprocess_call" in v_code
