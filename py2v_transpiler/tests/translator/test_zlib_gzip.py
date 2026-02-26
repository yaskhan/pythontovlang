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

def test_zlib_compress():
    source = """
import zlib
compressed = zlib.compress(b'hello')
"""
    v_code = translate(source)
    assert "import compress.zlib" in v_code
    assert "compressed := py_zlib_compress(b'hello')" in v_code

def test_zlib_decompress():
    source = """
import zlib
decompressed = zlib.decompress(b'compressed')
"""
    v_code = translate(source)
    assert "import compress.zlib" in v_code
    assert "decompressed := py_zlib_decompress(b'compressed')" in v_code

def test_gzip_compress():
    source = """
import gzip
compressed = gzip.compress(b'hello')
"""
    v_code = translate(source)
    assert "import compress.gzip" in v_code
    assert "compressed := py_gzip_compress(b'hello')" in v_code

def test_gzip_decompress():
    source = """
import gzip
decompressed = gzip.decompress(b'compressed')
"""
    v_code = translate(source)
    assert "import compress.gzip" in v_code
    assert "decompressed := py_gzip_decompress(b'compressed')" in v_code
