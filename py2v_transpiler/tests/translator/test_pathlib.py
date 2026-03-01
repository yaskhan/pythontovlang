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

def test_pathlib_creation():
    source = """
from pathlib import Path
p = Path("foo")
"""
    v_code = translate(source)
    assert "PyPath" in v_code
    assert 'py_path_new("foo")' in v_code or "py_path_new('foo')" in v_code

def test_pathlib_join():
    source = """
from pathlib import Path
p = Path("foo") / "bar"
"""
    v_code = translate(source)
    # V: p := py_path_new('foo') / 'bar'
    assert "/" in v_code

def test_pathlib_methods():
    source = """
from pathlib import Path
p = Path("foo")
if p.exists():
    pass
if p.is_file():
    pass
if p.is_dir():
    pass
"""
    v_code = translate(source)
    assert ".exists()" in v_code
    assert ".is_file()" in v_code
    assert ".is_dir()" in v_code

def test_pathlib_io():
    source = """
from pathlib import Path
p = Path("foo.txt")
text = p.read_text()
p.write_text("hello")
"""
    v_code = translate(source)
    assert ".read_text()" in v_code
    assert ".write_text(" in v_code
