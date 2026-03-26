import os
import subprocess
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_match_guards_transpilation():
    code = """
class User:
    def __init__(self, name: str):
        self.name = name

def check_user(u: object) -> str:
    match u:
        case User(name=n) if len(n) > 5:
            return "Long: " + n
        case User(name=n):
            return "Short: " + n
        case str(s) if s.startswith("a"):
            return "Starts with a: " + s
        case _:
            return "Other"

def test_main():
    assert check_user(User("Alice")) == "Short: Alice"
    assert check_user(User("Bob")) == "Short: Bob"
    assert check_user(User("Alexander")) == "Long: Alexander"
    assert check_user("apple") == "Starts with a: apple"
    assert check_user("banana") == "Other"
    assert check_user(123) == "Other"

if __name__ == "__main__":
    test_main()
"""
    parser = PyASTParser()
    analyzer = TypeInference()
    tree = parser.parse(code)
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    translator.visit_Module(tree)
    v_code = translator.emitter.emit()

    # Check for py_match_found flag
    assert "py_match_found" in v_code
    # Check for guard if block
    assert "if (n > 5)" in v_code or "if n.len > 5" in v_code or "if (n.len > 5)" in v_code

def test_match_guard_fallthrough():
    code = """
def check_val(x: object) -> str:
    match x:
        case int(n) if n > 10:
            return "Large int"
        case int(n):
            return "Small int"
        case _:
            return "Not an int"

def test_main():
    assert check_val(15) == "Large int"
    assert check_val(5) == "Small int"
    assert check_val("hi") == "Not an int"
"""
    parser = PyASTParser()
    analyzer = TypeInference()
    tree = parser.parse(code)
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    translator.visit_Module(tree)
    v_code = translator.emitter.emit()

    # Verify that we have separate if blocks for the pattern check
    # because match cases are translated to if/else if.
    # Pattern "int" is currently mapped to "Int" in SumTypes
    assert v_code.count("is Int") >= 2
