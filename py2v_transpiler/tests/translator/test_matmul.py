import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast

def transpile(code):
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    tree = ast.parse(code)
    return translator.visit_Module(tree)

def test_matmul_operator():
    code = "C = A @ B"
    v_code = transpile(code)
    assert "C := A.matmul(B)" in v_code

def test_matmul_augassign():
    code = "A @= B"
    v_code = transpile(code)
    assert "A = A.matmul(B)" in v_code
