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

def test_complex_literal():
    code = "z = 1 + 2j"
    v_code = transpile(code)
    assert "struct PyComplex" in v_code
    assert "py_complex(f64(1), 0.0) + py_complex(0.0, 2.0)" in v_code or "1 + py_complex(0.0, 2.0)" in v_code # Depending on wrap logic, my logic wraps 1

def test_complex_ops():
    code = "z = (1+2j) * (3+4j)"
    v_code = transpile(code)
    assert " * " in v_code # V operator overloading

def test_complex_mixed_ops():
    code = "z = 1 + (2+3j)"
    v_code = transpile(code)
    assert "py_complex(f64(1), 0.0)" in v_code

def test_complex_attributes():
    code = """
z = 1+2j
r = z.real
i = z.imag
"""
    v_code = transpile(code)
    assert "z.re" in v_code
    assert "z.im" in v_code
