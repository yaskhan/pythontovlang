import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile(code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)  # type: ignore[arg-type]

def test_none_initialization_untyped():
    code = "planner = None"
    v_code = transpile(code)
    # the analyzer falls back to 'Any' (formerly 'int') in _guess_type
    assert "mut planner := Any(NoneType{})" in v_code

def test_none_initialization_typed():
    code = "planner: Planner = None"
    v_code = transpile(code)
    assert "mut planner := ?Planner(none)" in v_code

def test_none_initialization_optional():
    code = "planner: Optional[int] = None"
    v_code = transpile(code)
    assert "mut planner := ?int(none)" in v_code

def test_none_initialization_optional_forward_ref():
    code = "planner: Optional['Packet'] = None"
    v_code = transpile(code)
    assert "mut planner := ?Packet(none)" in v_code

def test_optional_assignment_wrapping_string():
    code = """
def classify(score: int) -> None:
    if score >= 90:
        grade = 'A'
    elif score >= 80:
        grade = 'B'
"""
    v_code = transpile(code)
    assert "mut grade := ?string(none)" in v_code
    assert "grade = ?string('A')" in v_code
    assert "grade = ?string('B')" in v_code

def test_optional_assignment_wrapping_int():
    code = """
def get_value(x: int) -> None:
    if x > 10:
        result = 42
    elif x > 5:
        result = 99
"""
    v_code = transpile(code)
    assert "mut result := ?int(none)" in v_code
    assert "result = ?int(42)" in v_code
    assert "result = ?int(99)" in v_code

def test_optional_assignment_wrapping_skips_none():
    code = """
def maybe(flag: bool) -> None:
    if flag:
        val = 'hello'
"""
    v_code = transpile(code)
    assert "mut val := ?string(none)" in v_code
    assert "val = ?string('hello')" in v_code

def test_optional_assignment_wrapping_any():
    code = """
def f(flag: bool) -> None:
    if flag:
        x = 42
"""
    v_code = transpile(code)
    assert "mut x := ?int(none)" in v_code
    assert "x = ?int(42)" in v_code

def test_optional_assignment_wrapping_any_path():
    code = """
def f(d: dict) -> None:
    if d:
        v = d.get('key')
"""
    v_code = transpile(code)
    assert "mut v := ?" in v_code
    assert "v = ?int(" in v_code or "v = Any(" in v_code

def test_optional_assignment_wrapping_skips_none_rhs():
    code = """
def reset(flag: bool) -> None:
    if flag:
        val = 'hello'
    elif not flag:
        val = None
"""
    v_code = transpile(code)
    assert "mut val := ?string(none)" in v_code
    assert "val = ?string('hello')" in v_code
    assert "val = none" in v_code

def test_optional_assignment_no_double_wrap():
    code = """
def outer(flag: bool) -> None:
    if flag:
        grade = 'A'
    def inner(grade: str) -> None:
        pass
    if not flag:
        grade = 'B'
"""
    v_code = transpile(code)
    assert "grade = ?string('A')" in v_code
    assert "grade = ?string('B')" in v_code

def test_optional_assignment_no_double_wrap_on_optional_rhs():
    code = """
def f(flag: bool) -> None:
    other: Optional[str] = None
    if flag:
        grade = 'A'
    if other is not None:
        grade = 'B'
"""
    v_code = transpile(code)
    assert "mut grade := ?string(none)" in v_code
    assert "grade = ?string('A')" in v_code
    assert "grade = ?string('B')" in v_code
    assert "grade = ?string(?string(" not in v_code
