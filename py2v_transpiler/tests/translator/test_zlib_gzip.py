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
    # b'hello' -> [u8(0x68), u8(0x65), u8(0x6c), u8(0x6c), u8(0x6f)]
    assert "compressed := py_zlib_compress([u8(0x68), u8(0x65), u8(0x6c), u8(0x6c), u8(0x6f)])" in v_code

def test_zlib_decompress():
    source = """
import zlib
decompressed = zlib.decompress(b'compressed')
"""
    v_code = translate(source)
    assert "import compress.zlib" in v_code
    # b'compressed' -> [u8(0x63), u8(0x6f), u8(0x6d), u8(0x70), u8(0x72), u8(0x65), u8(0x73), u8(0x73), u8(0x65), u8(0x64)]
    assert "decompressed := py_zlib_decompress([u8(0x63), u8(0x6f), u8(0x6d), u8(0x70), u8(0x72), u8(0x65), u8(0x73), u8(0x73), u8(0x65), u8(0x64)])" in v_code

def test_gzip_compress():
    source = """
import gzip
compressed = gzip.compress(b'hello')
"""
    v_code = translate(source)
    assert "import compress.gzip" in v_code
    assert "compressed := py_gzip_compress([u8(0x68), u8(0x65), u8(0x6c), u8(0x6c), u8(0x6f)])" in v_code

def test_gzip_decompress():
    source = """
import gzip
decompressed = gzip.decompress(b'compressed')
"""
    v_code = translate(source)
    assert "import compress.gzip" in v_code
    assert "decompressed := py_gzip_decompress([u8(0x63), u8(0x6f), u8(0x6d), u8(0x70), u8(0x72), u8(0x65), u8(0x73), u8(0x73), u8(0x65), u8(0x64)])" in v_code
