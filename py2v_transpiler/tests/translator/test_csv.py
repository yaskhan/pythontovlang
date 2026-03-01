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
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_csv_reader():
    source = """
import csv
with open('data.csv') as f:
    reader = csv.reader(f)
    for row in reader:
        print(row)
"""
    v_code = translate(source)
    assert "PyCsvReader" in v_code
    assert "py_csv_reader" in v_code
    assert "csv.new_reader" in v_code # Inside helper

def test_csv_writer():
    source = """
import csv
with open('data.csv', 'w') as f:
    writer = csv.writer(f)
    writer.writerow(['a', 'b', 'c'])
"""
    v_code = translate(source)
    assert "PyCsvWriter" in v_code
    assert "py_csv_writer" in v_code
    assert ".writerow(" in v_code
