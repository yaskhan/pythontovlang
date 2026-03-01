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

def test_statistics_mean():
    source = """
import statistics
data = [1, 2, 3]
m = statistics.mean(data)
"""
    v_code = translate(source)
    assert "m := py_statistics_mean(data)" in v_code

def test_statistics_median():
    source = """
import statistics
data = [1, 2, 3]
m = statistics.median(data)
"""
    v_code = translate(source)
    assert "m := py_statistics_median(data)" in v_code

def test_statistics_mode():
    source = """
import statistics
data = [1, 2, 2, 3]
m = statistics.mode(data)
"""
    v_code = translate(source)
    assert "m := py_statistics_mode(data)" in v_code

def test_statistics_stdev():
    source = """
import statistics
data = [1.0, 2.0, 3.0]
s = statistics.stdev(data)
"""
    v_code = translate(source)
    assert "s := py_statistics_stdev(data)" in v_code

def test_statistics_variance():
    source = """
import statistics
data = [1.0, 2.0, 3.0]
v = statistics.variance(data)
"""
    v_code = translate(source)
    assert "v := py_statistics_variance(data)" in v_code
