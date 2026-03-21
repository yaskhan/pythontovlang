import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_matmul_operator():
    # Variables should become snake_case in V
    code = "A = Matrix(); B = Matrix(); C = A @ B"
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer)
    result = visitor.visit_Module(tree)
    
    assert "C = A.matmul(B)" in result

def test_matmul_augassign():
    code = "A = Matrix(); B = Matrix(); A @= B"
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    visitor = VNodeVisitor(analyzer)
    result = visitor.visit_Module(tree)
    
    assert "A = A.matmul(B)" in result
