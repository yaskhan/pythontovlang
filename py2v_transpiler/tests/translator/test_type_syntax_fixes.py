import pytest
from .utils import TranspilerTest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
import ast
from typing import cast

def translate(py_code: str) -> str:
    parser = PyASTParser()
    analyzer = TypeInference()
    tree = parser.parse(py_code)
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    translator.visit_Module(cast(ast.Module, tree))
    return translator.emitter.emit() + "\n" + translator.emitter.emit_helpers()

def test_fixed_size_tuple_mapping():
    py_code = """
def get_point(p: tuple[int, int]) -> tuple[int, int]:
    return p
"""
    v_code = translate(py_code)
    assert "fn get_point(p TupleStruct_IntInt) TupleStruct_IntInt {" in v_code
    assert "return p" in v_code

def test_heterogeneous_tuple_mapping():
    py_code = """
from typing import Tuple
def process_data(data: Tuple[int, str]):
    pass
"""
    v_code = translate(py_code)
    assert "fn process_data(data TupleStruct_IntString) {" in v_code

def test_union_to_named_sum_type():
    py_code = """
def handle_input(x: int | str):
    print(x)
"""
    v_code = translate(py_code)
    # Check that it uses a named sum type
    assert "type SumType_" in v_code
    assert "fn handle_input(x SumType_" in v_code

def test_optional_union_mapping():
    py_code = """
from typing import Optional, Union
def find_item(id: int) -> Optional[Union[str, int]]:
    return None
"""
    v_code = translate(py_code)
    assert "type SumType_" in v_code
    assert "fn find_item(id int) ?SumType_" in v_code

def test_dict_initialization_mapping():
    py_code = """
def create_map():
    d: dict[str, int] = dict()
    return d
"""
    v_code = translate(py_code)
    assert "d := map[string]int{}" in v_code

def test_map_any_casting():
    py_code = """
def get_any_map() -> dict[str, int | str]:
    return {"a": 1, "b": "hello"}
"""
    v_code = translate(py_code)
    assert "Any(1)" in v_code
    assert "Any('hello')" in v_code
