import ast
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator.module import ModuleMixin # VNodeVisitor likely inherits from this
from py2v_transpiler.core.parser import PyASTParser

# Instead of direct import which might be circular or complex, use what test_v2_features.py uses
# But test_v2_features.py imports VNodeVisitor from py2v_transpiler.core.translator

from py2v_transpiler.core.translator import VNodeVisitor

def transpile(code, mut_map=None):
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    if mut_map:
        analyzer.mutability_map.update(mut_map)
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    return v_code

def test_bytearray_translation():
    code = """
b1 = bytearray()
b2 = bytearray(10)
b3 = bytearray(b"abc")
b1[0] = 1
"""
    v_code = transpile(code)
    # Expected:
    # b1 := []u8{}
    # b2 := []u8{len: 10}
    # b3 := [u8(0x61), u8(0x62), u8(0x63)]
    # b1[0] = u8(1) // Python int literals usually map to int, but V []u8 expects u8

    assert "b1 := []u8{}" in v_code
    assert "b2 := []u8{len: 10}" in v_code
    assert "[u8(0x61), u8(0x62), u8(0x63)]" in v_code

def test_memoryview_translation():
    code = """
b = bytearray(b"abc")
m = memoryview(b)
m2 = m[1:2]
"""
    v_code = transpile(code)
    # V slices are already views
    assert "m := b" in v_code
    assert "m2 := m[1..2]" in v_code

def test_bytearray_mutability():
    # In V, []u8 is mutable if declared as mut
    code = """
def foo():
    b = bytearray(5)
    b[0] = 65
    b = b + b"abc"
    return b
"""
    # Force mutability for test by having reassignment
    # b is at line 3, col 4 (bytearray(5)) and line 5, col 4 (b + b"abc")
    mut_map = {"b": {"is_reassigned": True, "is_final": False}}
    v_code = transpile(code, mut_map=mut_map)
    assert "mut b := []u8{len: 5}" in v_code
    assert "b[0] = 65" in v_code

def test_bytearray_fromhex():
    code = "b = bytearray.fromhex('616263')"
    v_code = transpile(code)
    assert "import encoding.hex" in v_code
    assert "b := hex.decode('616263') or { []u8{} }" in v_code
