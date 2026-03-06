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

def test_overloaded_init_in_generic_class_argument_leak():
    source = """
from typing import overload, Generic, TypeVar

T = TypeVar('T')

class Container(Generic[T]):
    @overload
    def __init__(self, item: T) -> None: ...
    @overload
    def __init__(self, item: int) -> None: ...
    def __init__(self, item: T | int) -> None:
        pass
"""
    v_code = translate(source)
    # Generic parameter T should be mapped to 'generic' in function name to avoid leak
    assert "fn new_container_generic[T]" in v_code
    assert "fn new_container_int[T]" in v_code

def test_overloaded_init_in_generic_class_nested_leak():
    source = """
from typing import overload, Generic, TypeVar, List

T = TypeVar('T')

class UserList(Generic[T]):
    @overload
    def __init__(self, data: List[T]) -> None: ...
    @overload
    def __init__(self, data: None) -> None: ...
    def __init__(self, data: List[T] | None = None) -> None:
        pass
"""
    v_code = translate(source)
    # List[T] -> []T. T should be replaced by 'generic' in the name
    assert "fn new_user_list_arr_generic[T]" in v_code
    assert "fn new_user_list_none[T]" in v_code

def test_overloaded_init_in_pydantic_model():
    source = """
from pydantic import BaseModel
from typing import overload

class User(BaseModel):
    name: str
    age: int

    @overload
    def __init__(self, name: str, age: int) -> None: ...
    @overload
    def __init__(self, name: str) -> None: ...
    def __init__(self, name: str, age: int = 0) -> None:
        self.name = name
        self.age = age
"""
    v_code = translate(source)
    # Pydantic models should have ! Result type and validate() call
    assert "fn new_user_string_int(name string, age int) !User {" in v_code
    assert "fn new_user_string(name string) !User {" in v_code
    assert "self.validate() or { return err }" in v_code
    assert "mut self := User{}" in v_code

if __name__ == "__main__":
    test_overloaded_init_in_generic_class()
    test_overloaded_init_in_generic_class_argument_leak()
    test_overloaded_init_in_generic_class_nested_leak()
    test_overloaded_init_in_pydantic_model()
    print("Tests passed!")
