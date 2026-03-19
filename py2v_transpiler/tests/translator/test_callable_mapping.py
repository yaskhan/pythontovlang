import ast
from typing import cast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(py_code: str) -> str:
    parser = PyASTParser()
    analyzer = TypeInference()
    tree = parser.parse(py_code)
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(cast(ast.Module, tree))

def test_simple_callable():
    py_code = """
from typing import Callable
def apply(f: Callable[[int], int], x: int) -> int:
    return f(x)
"""
    v_code = translate(py_code)
    assert "fn apply(f fn (int) int, x int) int {" in v_code

def test_multiple_arguments_callable():
    py_code = """
from typing import Callable
def process(f: Callable[[int, str], bool], x: int, s: str) -> bool:
    return f(x, s)
"""
    v_code = translate(py_code)
    assert "fn process(f fn (int, string) bool, x int, s string) bool {" in v_code

def test_no_return_value_callable():
    py_code = """
from typing import Callable
def execute(f: Callable[[], None]) -> None:
    f()
"""
    v_code = translate(py_code)
    assert "fn execute(f fn ()) {" in v_code

def test_variadic_callable():
    py_code = """
from typing import Callable, Any
def call_any(f: Callable[..., Any], *args: Any) -> Any:
    return f(*args)
"""
    v_code = translate(py_code)
    assert "fn call_any(f fn (...Any) Any, args ...Any) Any {" in v_code

def test_lowercase_callable():
    py_code = """
def apply(f: callable, x: int) -> int:
    return f(x)
"""
    v_code = translate(py_code)
    assert "fn apply(f fn (...Any) Any, x int) int {" in v_code

def test_collections_abc_callable():
    py_code = """
import collections.abc
def apply(f: collections.abc.Callable[[int], int], x: int) -> int:
    return f(x)
"""
    v_code = translate(py_code)
    assert "fn apply(f fn (int) int, x int) int {" in v_code

def test_complex_comprehension_with_callable():
    py_code = """
from typing import Callable
def apply_function(f: Callable[[int], int], values: list[int]) -> list[int]:
    return [f(v) for v in values]
"""
    v_code = translate(py_code)
    assert "fn apply_function(f fn (int) int, values []int) []int {" in v_code
    assert "py_comp_1 << f(v)" in v_code
