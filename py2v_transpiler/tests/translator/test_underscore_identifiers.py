from py2v_transpiler.tests.translator.utils import TranspilerTest

def test_underscore_variables():
    test = TranspilerTest()
    source = """
_global = 1
def func():
    _local = 2
    _ = 3
    print(_local)
    print(_)
"""
    # Identifiers starting with _ are prefixed with py
    # _ is write-only in V, so it is sanitized to py_ everywhere.
    expected_v_code = """
fn func() {
    py_local := 2
    py_ := 3
    println('${py_local}')
    println('${py_}')
}
fn main() {
    py_global := 1
}
"""
    test.assert_transpilation(source, expected_v_code)

def test_private_fields():
    test = TranspilerTest()
    source = """
class User:
    def __init__(self, _name: str):
        self._name = _name
        self.__secret = 42
"""
    # Fields are in mut: block and prefixed with py
    expected_v_code = """
struct User {
mut:
    py_name string
    py__user_secret int
}

fn new_user(py_name string) User {
    mut self := User{}
    self.py_name = py_name
    self.py__user_secret = 42
    return self
}
"""
    test.assert_transpilation(source, expected_v_code)

def test_operator_overloading_preservation():
    test = TranspilerTest()
    source = """
class Vector:
    def __add__(self, other: 'Vector') -> 'Vector':
        return Vector()
"""
    v_code = test.transpile_to_str(source)
    assert "fn (self Vector) + (other Vector) Vector {" in v_code
    assert "py__add__" not in v_code

def test_dunder_preservation():
    test = TranspilerTest()
    source = """
class Foo:
    def __str__(self) -> str:
        return "foo"
"""
    v_code = test.transpile_to_str(source)
    assert "fn (self Foo) str() string {" in v_code
    assert "py__str__" not in v_code
