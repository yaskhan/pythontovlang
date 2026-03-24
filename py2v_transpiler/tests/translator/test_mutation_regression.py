import textwrap
import pytest
import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    # print(f"DEBUG MUTABILITY MAP: {analyzer.mutability_map}")
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    return v_code

def test_interprocedural_dict_mutation():
    source = """
def process(data: dict) -> None:
    data['key'] = 'value'

def wrapper(d: dict) -> None:
    process(d)
"""
    v_code = translate(source)
    # print(f"DEBUG V CODE:\n{v_code}")
    assert "fn process(mut data map[string]int)" in v_code
    assert "fn wrapper(mut d map[string]int)" in v_code
    assert "process(mut d)" in v_code

def test_interprocedural_list_mutation():
    source = """
def process(lst: list) -> None:
    lst.append(1)

def wrapper(l: list) -> None:
    process(l)
"""
    v_code = translate(source)
    assert "fn process(mut lst []int)" in v_code
    assert "fn wrapper(mut l []int)" in v_code
    assert "process(mut l)" in v_code

def test_interprocedural_attr_mutation():
    source = """
class Data:
    def __init__(self):
        self.val = 0

def modify(obj: Data) -> None:
    obj.val = 1

def wrapper(obj: Data) -> None:
    modify(obj)
"""
    v_code = translate(source)
    assert "fn modify(mut obj &Data)" in v_code
    assert "fn wrapper(mut obj &Data)" in v_code
    assert "modify(mut obj)" in v_code

def test_collection_methods_mutability():
    source = """
def test_dict(d: dict):
    d.update({'a': 1})
    d.pop('b')
    d.clear()

def test_list(l: list):
    l.insert(0, 1)
    l.extend([2, 3])
    l.remove(1)
    l.pop()

def test_set(s: set):
    s.add(1)
    s.discard(2)
"""
    v_code = translate(source)
    assert "fn test_dict(mut d map[string]int)" in v_code
    assert "fn test_list(mut l []int)" in v_code
    assert "fn test_set(mut s datatypes.Set[int])" in v_code
