import os
import subprocess
import pytest

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
    with open("temp_match_guards.py", "w") as f:
        f.write(code)

    try:
        # Transpile
        import sys
        project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        result = subprocess.run([sys.executable, "py2v_transpiler/main.py", "temp_match_guards.py"],
                               capture_output=True, text=True, env={**os.environ, "PYTHONPATH": project_root})
        assert result.returncode == 0, f"Transpilation failed: {result.stderr}"

        # Verify generated V code
        with open("temp_match_guards.v", "r") as f:
            v_code = f.read()

        # Check for py_match_found flag
        assert "py_match_found_1" in v_code
        # Check for guard if block with parentheses
        assert "if (n.len > 5) {" in v_code

    finally:
        if os.path.exists("temp_match_guards.py"): os.remove("temp_match_guards.py")
        if os.path.exists("temp_match_guards.v"): os.remove("temp_match_guards.v")
        if os.path.exists("temp_match_guards_helpers.v"): os.remove("temp_match_guards_helpers.v")

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
    with open("temp_fallthrough.py", "w") as f:
        f.write(code)

    try:
        # Transpile
        import sys
        project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        result = subprocess.run([sys.executable, "py2v_transpiler/main.py", "temp_fallthrough.py"],
                               capture_output=True, text=True, env={**os.environ, "PYTHONPATH": project_root})
        assert result.returncode == 0

        with open("temp_fallthrough.v", "r") as f:
            v_code = f.read()

        # Verify that we have separate if blocks for the same pattern 'int'
        # because we refactored it to separate blocks.
        assert v_code.count("is Int") >= 2

    finally:
        if os.path.exists("temp_fallthrough.py"): os.remove("temp_fallthrough.py")
        if os.path.exists("temp_fallthrough.v"): os.remove("temp_fallthrough.v")
        if os.path.exists("temp_fallthrough_helpers.v"): os.remove("temp_fallthrough_helpers.v")
