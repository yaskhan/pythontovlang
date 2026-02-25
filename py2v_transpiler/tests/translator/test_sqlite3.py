import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

def test_sqlite3_connect():
    source = """
import sqlite3
conn = sqlite3.connect('test.db')
c = conn.cursor()
c.execute('CREATE TABLE stocks (date text, trans text, symbol text, qty real, price real)')
conn.commit()
conn.close()
"""
    v_code = translate(source)
    assert "PySqliteConnection" in v_code
    assert "py_sqlite_connect" in v_code
    assert ".cursor()" in v_code
    assert ".execute(" in v_code
    assert ".commit()" in v_code
    assert ".close()" in v_code

def test_sqlite3_fetch():
    source = """
import sqlite3
conn = sqlite3.connect('test.db')
c = conn.cursor()
c.execute('SELECT * FROM stocks')
rows = c.fetchall()
"""
    v_code = translate(source)
    assert ".fetchall()" in v_code
