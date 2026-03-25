import pytest
import sys
from py2v_transpiler.tests.test_pep695 import transpile_code

@pytest.mark.skipif(sys.version_info < (3, 12), reason="PEP 695 type parameters require Python 3.12+")
def test_fn_pointer():
    code = """
import typing
class Cached_property[T]:
    fn: typing.Callable[[typing.Any], T]
    attrname: typing.Optional[str]
"""
    v_code = transpile_code(code)
    assert "py_fn fn (Any) T" in v_code

@pytest.mark.skipif(sys.version_info < (3, 12), reason="PEP 695 type parameters require Python 3.12+")
def test_fn_pointer_with_default():
    code = """
import typing
class Cached_property[T]:
    fn: typing.Callable[[typing.Any], T] = my_func
"""
    v_code = transpile_code(code)
    assert "py_fn fn (Any) T = my_func" in v_code
