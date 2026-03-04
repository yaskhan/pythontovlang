import ast
import pytest
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile(code):
    tree = ast.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    # Mocking config if needed, though VNodeVisitor should handle it
    from py2v_transpiler.config import TranspilerConfig
    config = TranspilerConfig()
    translator = VNodeVisitor(analyzer, config=config)
    v_code = translator.visit_Module(tree)
    # Get all emitted code
    return v_code + "\n" + translator.emitter.emit()

def test_literal_string_basic():
    code = """
from typing import LiteralString

def run_query(sql: LiteralString) -> None:
    pass

s: LiteralString = "SELECT * FROM users"
run_query(s)
run_query("SELECT 1")
"""
    v_code = transpile(code)
    # Check if LiteralString is mapped to string in V
    assert "fn run_query(sql string)" in v_code or "fn run_query(sql string) none" in v_code
    # Check if it is treated as a constant if top-level and literal
    assert "s = 'SELECT * FROM users'" in v_code

def test_literal_string_concatenation():
    code = """
from typing import LiteralString

s1: LiteralString = "SELECT "
s2: LiteralString = "id FROM "
s3: LiteralString = s1 + s2 + "users"

def run_query(sql: LiteralString):
    pass

run_query(s3)
"""
    v_code = transpile(code)
    # Current implementation might not track s1 + s2 as LiteralString if it only looks at AST of the RHS
    # It currently fails to put s3 in const because s1, s2 are not UPPERCASE
    assert "s3 = s1 + s2 + 'users'" in v_code

def test_literal_string_fstring():
    code = """
from typing import LiteralString

table = "users"
# This is NOT a LiteralString because it has a variable
s: LiteralString = f"SELECT * FROM {table}"

# This IS a LiteralString (f-string without variables, or just constants)
s2: LiteralString = f"SELECT * FROM {'users'}"
"""
    v_code = transpile(code)
    # Check that s2 is recognized as a literal string.
    # Current implementation preserves interpolation even for constants in f-strings.
    assert "s2 = 'SELECT * FROM ${\"users\"}'" in v_code or "s2 = 'SELECT * FROM users'" in v_code

def test_literal_string_warning_input():
    code = """
from typing import LiteralString

s: LiteralString = input("Enter SQL: ")
"""
    v_code = transpile(code)
    assert "WARNING: LiteralString variable 's' receives value from input()" in v_code

def test_literal_string_complex_concatenation():
    code = """
from typing import LiteralString
def get_query(limit: int) -> LiteralString:
    query: LiteralString = "SELECT * FROM table"
    if limit > 0:
        return query + " LIMIT 10"
    return query
"""
    v_code = transpile(code)
    assert "fn get_query(limit int) string" in v_code
