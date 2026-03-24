import ast
import pytest
from py2v_transpiler.core.analyzer import TypeInference

def test_guess_node_type_empty_dict():
    analyzer = TypeInference()
    node = ast.Dict(keys=[], values=[])
    assert analyzer._guess_node_type(node) == "map[string]Any"

def test_guess_node_type_dict_with_elements():
    analyzer = TypeInference()
    # { "a": 1 }
    node = ast.Dict(
        keys=[ast.Constant(value="a")],
        values=[ast.Constant(value=1)]
    )
    assert analyzer._guess_node_type(node) == "map[string]int"

def test_guess_node_type_dict_with_mixed_elements():
    analyzer = TypeInference()
    # { "a": 1, 2: "b" }
    node = ast.Dict(
        keys=[ast.Constant(value="a"), ast.Constant(value=2)],
        values=[ast.Constant(value=1), ast.Constant(value="b")]
    )
    # k_type becomes Any because len(key_types) > 1
    # v_type becomes Any because len(val_types) > 1
    assert analyzer._guess_node_type(node) == "map[Any]Any"

def test_guess_node_type_empty_list():
    analyzer = TypeInference()
    node = ast.List(elts=[], ctx=ast.Load())
    assert analyzer._guess_node_type(node) == "[]Any"

def test_guess_node_type_list_with_elements():
    analyzer = TypeInference()
    # [1, 2, 3]
    node = ast.List(
        elts=[ast.Constant(value=1), ast.Constant(value=2), ast.Constant(value=3)],
        ctx=ast.Load()
    )
    assert analyzer._guess_node_type(node) == "[]int"

def test_guess_node_type_list_with_mixed_elements():
    analyzer = TypeInference()
    # [1, "a"]
    node = ast.List(
        elts=[ast.Constant(value=1), ast.Constant(value="a")],
        ctx=ast.Load()
    )
    # _find_lcs([int, string]) -> Any
    assert analyzer._guess_node_type(node) == "[]Any"
