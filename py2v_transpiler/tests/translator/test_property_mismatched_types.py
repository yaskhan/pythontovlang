import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_property_setter_with_union_type():
    """Test for property with different types in getter and setter

    When setter accepts union type (str | int), Any is used in V
    """
    source = """
class Config:
    _value: int = 0

    def __init__(self):
        self._value = 0

    @property
    def value(self) -> int:
        return self._value

    @value.setter
    def value(self, new_value: str | int):
        if isinstance(new_value, str):
            self._value = int(new_value)
        else:
            self._value = new_value
"""
    expected_fragments = [
        "fn (self Config) value() int {",
        "return self._value",
        "}",
        # Union type is now preserved in setter
        "fn (mut self Config) set_value(new_value SumType_IntString) {",
        "if new_value is str {",
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code:")
    print(code)
    print()

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"


def test_property_setter_with_string_type():
    """Test for property where setter accepts str and getter returns int"""
    source = """
class Converter:
    _count: int = 0

    def __init__(self):
        self._count = 0

    @property
    def count(self) -> int:
        return self._count

    @count.setter
    def count(self, value: str):
        self._count = int(value)
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for string setter:")
    print(code)
    print()

    # Check that getter returns int
    assert "fn (self Converter) count() int {" in code
    # Check that setter accepts string
    assert "fn (mut self Converter) set_count(value string) {" in code


def test_property_with_optional_types():
    """Test for property where setter accepts Optional type"""
    source = """
from typing import Optional

class DataHolder:
    _data: Optional[str] = None

    def __init__(self):
        self._data = None

    @property
    def data(self) -> Optional[str]:
        return self._data

    @data.setter
    def data(self, value: str | None):
        self._data = value
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for optional types:")
    print(code)
    print()

    # Check that getter returns ?string
    assert "fn (self DataHolder) data() ?string {" in code
    # Check that setter accepts ?string
    assert "fn (mut self DataHolder) set_data(value ?string) {" in code


def test_property_getter_union_setter_single():
    """Test where getter returns union and setter accepts a single type"""
    source = """
class Result:
    _value: int = 0

    def __init__(self):
        self._value = 0

    @property
    def value(self) -> int | str:
        return self._value

    @value.setter
    def value(self, new_value: int):
        self._value = new_value
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for getter with union:")
    print(code)
    print()

    # Getter with union type should use union
    assert "fn (self Result) value() SumType_IntString {" in code
    # Setter accepts int
    assert "fn (mut self Result) set_value(new_value int) {" in code


def test_property_no_type_hints():
    """Test for property without type annotations"""
    source = """
class Simple:
    def __init__(self):
        self._x = 0

    @property
    def x(self):
        return self._x

    @x.setter
    def x(self, value):
        self._x = value
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code without type hints:")
    print(code)
    print()

    # Without annotations, void is used for return and int for arguments by default
    assert "fn (self Simple) x() {" in code
    assert "fn (mut self Simple) set_x(value int) {" in code


def test_property_float_int_conversion():
    """Test for property with float <-> int conversion"""
    source = """
class Measurement:
    _value: float = 0.0

    def __init__(self):
        self._value = 0.0

    @property
    def value(self) -> float:
        return self._value

    @value.setter
    def value(self, new_value: int | float):
        self._value = float(new_value)
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for float/int property:")
    print(code)
    print()

    # Getter returns f64
    assert "fn (self Measurement) value() f64 {" in code
    # Setter accepts union type
    assert "fn (mut self Measurement) set_value(new_value SumType_F64Int) {" in code
