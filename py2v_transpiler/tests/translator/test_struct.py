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

def test_struct_pack_le_u32():
    source = """
import struct
x = 1
buf = struct.pack('<I', x)
"""
    v_code = translate(source)
    assert "import encoding.binary" in v_code
    assert "buf := py_struct_pack_I_le(u32(x))" in v_code

def test_struct_pack_be_u32():
    source = """
import struct
x = 1
buf = struct.pack('>I', x)
"""
    v_code = translate(source)
    assert "buf := py_struct_pack_I_be(u32(x))" in v_code

def test_struct_unpack_le_u32():
    # Use escaped backslashes to avoid actual null bytes in the source string
    source = """
import struct
buf = b'\\x01\\x00\\x00\\x00'
val = struct.unpack('<I', buf)
"""
    v_code = translate(source)
    assert "val := py_struct_unpack_I_le(buf)" in v_code

def test_struct_pack_generic():
    source = """
import struct
buf = struct.pack('fmt', 1)
"""
    v_code = translate(source)
    # Generic fallback
    assert "buf := py_struct_pack('fmt', 1)" in v_code
