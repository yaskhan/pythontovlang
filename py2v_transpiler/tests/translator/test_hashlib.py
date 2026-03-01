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

def test_hashlib_sha256():
    source = """
import hashlib
h = hashlib.sha256(b"hello")
h.update(b"world")
d = h.hexdigest()
"""
    v_code = translate(source)
    assert "py_hash_sha256" in v_code
    assert ".update" in v_code
    assert ".hexdigest" in v_code

def test_hashlib_md5():
    source = """
import hashlib
h = hashlib.md5()
h.update(b"hello")
d = h.hexdigest()
"""
    v_code = translate(source)
    assert "py_hash_md5" in v_code
    assert ".update" in v_code
    assert ".hexdigest" in v_code
