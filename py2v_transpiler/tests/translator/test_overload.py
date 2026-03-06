import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_overloaded_init_in_generic_class():
    source = """
from typing import overload, Generic, TypeVar

T = TypeVar('T')

class UserDict(Generic[T]):
    @overload
    def __init__(self, data: dict) -> None: ...
    @overload
    def __init__(self, data: None) -> None: ...
    def __init__(self, data: dict | None = None) -> None:
        pass
"""
    v_code = translate(source)
    # Check that it generates factory functions (new_user_dict_...)
    # and NOT methods (__init___...)
    assert "fn new_user_dict_map_stringint[T]" in v_code
    assert "fn new_user_dict_none[T]" in v_code
    # Ensure it returns the correct generic type
    assert "fn new_user_dict_map_stringint[T](data map[string]int) UserDict[T] {" in v_code
    assert "fn new_user_dict_none[T](data none) UserDict[T] {" in v_code
    # Ensure it doesn't have T in the function name itself (e.g. new_user_dict_T_...)
    assert "new_user_dict_T" not in v_code
