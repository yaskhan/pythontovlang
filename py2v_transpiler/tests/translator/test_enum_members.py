import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference


def test_enum_unannotated_members():
    """Тест для Enum с неаннотированными членами (классический синтаксис)"""
    source = """
from enum import Enum

class Color(Enum):
    RED = 1
    GREEN = 2
    BLUE = 3
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for unannotated enum:")
    print(code)
    print()

    assert "enum Color {" in code
    assert "red = 1" in code
    assert "green = 2" in code
    assert "blue = 3" in code


def test_enum_annotated_members():
    """Тест для Enum с аннотированными членами (PEP 736 стиль)"""
    source = """
from enum import Enum

class Color(Enum):
    RED: int = 1
    GREEN: int = 2
    BLUE: int = 3
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for annotated enum:")
    print(code)
    print()

    assert "enum Color {" in code
    # Аннотированные члены должны быть обработаны
    assert "red" in code
    assert "green" in code
    assert "blue" in code


def test_enum_mixed_members():
    """Тест для Enum со смешанными членами (аннотированные и нет)"""
    source = """
from enum import Enum

class Status(Enum):
    PENDING: int = 1
    RUNNING = 2
    DONE: int = 3
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for mixed enum:")
    print(code)
    print()

    assert "enum Status {" in code
    assert "pending" in code
    assert "running" in code
    assert "done" in code


def test_intenum_annotated():
    """Тест для IntEnum с аннотированными членами"""
    source = """
from enum import IntEnum

class Priority(IntEnum):
    LOW: int = 1
    MEDIUM: int = 2
    HIGH: int = 3
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for annotated IntEnum:")
    print(code)
    print()

    assert "enum Priority {" in code
    assert "low" in code
    assert "medium" in code
    assert "high" in code


def test_enum_with_auto():
    """Тест для Enum с auto() значениями"""
    source = """
from enum import Enum, auto

class State(Enum):
    IDLE = auto()
    RUNNING = auto()
    DONE = auto()
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for enum with auto():")
    print(code)
    print()

    assert "enum State {" in code
    # auto() должен быть развернут в числа
    assert "idle" in code
    assert "running" in code
    assert "done" in code


def test_enum_string_members():
    """Тест для Enum со строковыми значениями"""
    source = """
from enum import Enum

class Direction(Enum):
    NORTH = "north"
    SOUTH = "south"
    EAST = "east"
    WEST = "west"
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print("Generated code for string enum:")
    print(code)
    print()

    assert "enum Direction {" in code
    assert "north" in code.lower()
    assert "south" in code.lower()
