import pytest
import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.config import TranspilerConfig

def transpile(code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(code)

    analyzer = TypeInference()
    analyzer.analyze(tree)

    config = TranspilerConfig()
    visitor = VNodeVisitor(analyzer, config)
    return visitor.visit_Module(tree)

def test_list_extend_simple():
    code = """
def test():
    result = []
    result.extend([1, 2, 3])
    return result
"""
    v_code = transpile(code)
    assert "result << [1, 2, 3]" in v_code

def test_list_extend_variable():
    code = """
def test(values: list[int]):
    result = []
    result.extend(values)
    return result
"""
    v_code = transpile(code)
    assert "result << values" in v_code

def test_list_extend_dict_values():
    code = """
def test(data: dict[str, list[int]]):
    result = []
    for values in data.values():
        result.extend(values)
    return result
"""
    v_code = transpile(code)
    assert "result << values" in v_code

def test_list_extend_generator():
    code = """
def test():
    result = []
    result.extend(x * 2 for x in range(5))
    return result
"""
    v_code = transpile(code)
    assert "result << py_comp" in v_code
