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

def test_multiple_classes_overloaded_init():
    source = """
from typing import overload

class A:
    @overload
    def __init__(self, x: int) -> None: ...
    def __init__(self, x: int) -> None:
        pass

class B:
    @overload
    def __init__(self, y: str) -> None: ...
    def __init__(self, y: str) -> None:
        pass

a = A(1)
b = B("s")
"""
    v_code = translate(source)
    assert "fn new_a_int(x int) A {" in v_code
    assert "fn new_b_string(y string) B {" in v_code
    # Ensure no cross-pollination of overloads
    assert "fn new_a_string" not in v_code
    assert "fn new_b_int" not in v_code
    # Check call sites
    assert "a := new_a_int(1)" in v_code
    assert "b := new_b_string('s')" in v_code

def test_overloaded_new_and_init():
    source = """
from typing import overload

class Multi:
    @overload
    def __new__(cls, x: int) -> "Multi": ...
    @overload
    def __new__(cls, x: str) -> "Multi": ...
    def __new__(cls, x: int | str) -> "Multi":
        return object.__new__(cls)

    @overload
    def __init__(self, x: int) -> None: ...
    @overload
    def __init__(self, x: str) -> None: ...
    def __init__(self, x: int | str) -> None:
        pass

m1 = Multi(1)
m2 = Multi("a")
"""
    v_code = translate(source)
    # When __new__ is present, it should be the factory
    assert "fn new_multi_int(x int) Multi {" in v_code
    assert "fn new_multi_string(x string) Multi {" in v_code
    # __init__ should be a regular method named 'init'
    assert "fn (mut self Multi) init_int(x int)" in v_code
    assert "fn (mut self Multi) init_string(x string)" in v_code
    # Check call sites
    assert "m1 := new_multi_int(1)" in v_code
    assert "m2 := new_multi_string('a')" in v_code

def test_overloaded_regular_method():
    source = """
from typing import overload

class Calculator:
    @overload
    def add(self, x: int) -> int: ...
    @overload
    def add(self, x: str) -> str: ...
    def add(self, x: int | str) -> int | str:
        return x

c = Calculator()
r1 = c.add(1)
r2 = c.add("s")
"""
    v_code = translate(source)
    assert "fn (self Calculator) add_int(x int) int {" in v_code
    assert "fn (self Calculator) add_string(x string) string {" in v_code
    assert "r1 := c.add_int(1)" in v_code
    assert "r2 := c.add_string('s')" in v_code

if __name__ == "__main__":
    test_overloaded_init_in_generic_class()
    test_overloaded_init_in_generic_class_argument_leak()
    test_overloaded_init_in_generic_class_nested_leak()
    test_overloaded_init_in_pydantic_model()
    print("Tests passed!")
