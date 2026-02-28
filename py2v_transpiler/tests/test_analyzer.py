import ast
import pytest
from unittest.mock import patch, MagicMock
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.models.v_types import map_python_type_to_v

def test_map_python_type_to_v():
    assert map_python_type_to_v("int") == "int"
    assert map_python_type_to_v("float") == "f64"
    assert map_python_type_to_v("str") == "string"
    assert map_python_type_to_v("bool") == "bool"
    assert map_python_type_to_v("None") == "none"

def test_analyze_variable_annotation():
    analyzer = TypeInference()
    code = "x: int = 1"
    tree = ast.parse(code)
    analyzer.analyze(tree)

    assert analyzer.type_map["x"] == "int"

def test_analyze_string_annotation():
    analyzer = TypeInference()
    code = "x: 'int' = 1"
    tree = ast.parse(code)
    analyzer.analyze(tree)

    assert analyzer.type_map["x"] == "int"

def test_analyze_function_annotation():
    analyzer = TypeInference()
    code = "def foo(a: str, b: int): pass"
    tree = ast.parse(code)
    analyzer.analyze(tree)

    assert analyzer.type_map["a"] == "string"
    assert analyzer.type_map["b"] == "int"

def test_resolve_type():
    analyzer = TypeInference()
    code = "x: int = 1"
    tree = ast.parse(code)
    analyzer.analyze(tree)

    # Simulate resolving a Name node
    name_node = ast.Name(id="x")
    assert analyzer.resolve_type(name_node) == "int"

    unknown_node = ast.Name(id="y")
    assert analyzer.resolve_type(unknown_node) == "void"

@patch("py2v_transpiler.core.analyzer.mypy_api_module")
def test_run_mypy(mock_mypy):
    # Setup mock
    mock_mypy.run.return_value = ("Success", "", 0)

    analyzer = TypeInference()
    stdout, stderr, code = analyzer.run_mypy("test.py")

    assert stdout == "Success"
    assert stderr == ""
    assert code == 0

    args = mock_mypy.run.call_args[0][0]
    assert args[0] == "test.py"
    assert args[1] == "--config-file"

def test_run_mypy_no_module():
    # To test the ImportError case, we'd need to manipulate sys.modules or use a separate process.
    # For now, let's just ensure if mypy_api_module is None (simulated), it returns error.

    with patch("py2v_transpiler.core.analyzer.mypy_api_module", None):
        analyzer = TypeInference()
        stdout, stderr, code = analyzer.run_mypy("test.py")
        assert stdout == "Mypy not installed."
        assert code == 1
