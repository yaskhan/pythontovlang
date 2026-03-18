import pytest
from py2v_transpiler.main import Transpiler

def transpile_code(code: str) -> str:
    return Transpiler().transpile(code)

def test_hashlib_update_not_dict_update():
    code = """
import hashlib
h = hashlib.sha256()
h.update(b'hello')
"""
    v_code = transpile_code(code)
    # Check for hashlib's update (no mut py_dict_update wrapping)
    assert "h.update(" in v_code
    assert "py_dict_update" not in v_code

def test_dict_update():
    code = """
d = {'a': 1}
d.update({'b': 2})
"""
    v_code = transpile_code(code)
    assert "py_dict_update" in v_code
