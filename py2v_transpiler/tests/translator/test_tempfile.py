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

def test_gettempdir():
    source = """
import tempfile
d = tempfile.gettempdir()
"""
    v_code = translate(source)
    assert "d := os.temp_dir()" in v_code
    assert "import os" in v_code

def test_mkdtemp():
    source = """
import tempfile
d = tempfile.mkdtemp()
"""
    v_code = translate(source)
    # V: os.mkdir_temp or os.temp_dir() + path
    # Expected output: os.mkdir_all(os.temp_dir() + '/random')
    # Actually V has no direct mkdtemp equivalent in os module (only create_temp for file).
    # We might need to generate a unique name.
    # For now, let's see what we decide to implement.
    # Maybe map to custom helper?
    assert "d := os.mkdir_temp('')" in v_code or "d := os.mkdir_all" in v_code # We'll need to confirm mapping

def test_named_temporary_file():
    source = """
import tempfile
with tempfile.NamedTemporaryFile() as f:
    pass
"""
    v_code = translate(source)
    # This should be mapped to os.create_temp('') and defer close/remove
    assert "os.create_temp" in v_code
    assert "defer" in v_code

def test_temporary_directory():
    source = """
import tempfile
with tempfile.TemporaryDirectory() as d:
    pass
"""
    v_code = translate(source)
    # Map to os.mkdir_temp and defer rmdir_all
    assert "os.mkdir_temp" in v_code or "os.mkdir_all" in v_code
    assert "defer" in v_code
    assert "rmdir_all" in v_code
