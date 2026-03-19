import pytest
from py2v_transpiler.tests.translator.test_list_operations import transpile

def test_issue_extend_v_spreading():
    code = """
def complex_dict(data: dict[str, list[int]]) -> list[int]:
    result: list[int] = []
    for key, values in data.items():
        result.extend(values)
    return result
"""
    v_code = transpile(code)
    assert "result << ...values" in v_code

def test_list_extend_literal():
    code = """
def test():
    result = []
    result.extend([1, 2, 3])
    return result
"""
    v_code = transpile(code)
    assert "result << ...[1, 2, 3]" in v_code
