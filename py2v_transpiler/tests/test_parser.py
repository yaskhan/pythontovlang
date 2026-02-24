import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser

def test_parse_valid_code():
    parser = PyASTParser()
    code = "x = 1"
    tree = parser.parse(code)
    assert isinstance(tree, ast.AST)
    assert isinstance(tree, ast.Module)

def test_parse_invalid_code():
    parser = PyASTParser()
    code = "x = "
    with pytest.raises(SyntaxError):
        parser.parse(code)

def test_parse_file_valid(tmp_path):
    parser = PyASTParser()
    code = "print('hello')"
    file_path = tmp_path / "test.py"
    file_path.write_text(code, encoding="utf-8")

    tree = parser.parse_file(str(file_path))
    assert isinstance(tree, ast.AST)

def test_parse_file_not_found():
    parser = PyASTParser()
    with pytest.raises(FileNotFoundError):
        parser.parse_file("non_existent_file.py")

def test_parse_file_invalid_syntax(tmp_path):
    parser = PyASTParser()
    code = "def foo("
    file_path = tmp_path / "invalid.py"
    file_path.write_text(code, encoding="utf-8")

    with pytest.raises(SyntaxError):
        parser.parse_file(str(file_path))
