import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_bytes_literal_ascii():
    code = "b = b'abc'"
    v_code = transpile(code)
    # [u8(0x61), u8(0x62), u8(0x63)]
    assert "[u8(0x61), u8(0x62), u8(0x63)]" in v_code

def test_bytes_literal_hex():
    code = "b = b'\\x00\\xff'"
    v_code = transpile(code)
    assert "[u8(0x00), u8(0xff)]" in v_code

def test_bytes_literal_empty():
    code = "b = b''"
    v_code = transpile(code)
    assert "[]u8{}" in v_code
