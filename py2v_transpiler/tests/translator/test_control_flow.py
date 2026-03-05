import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_if():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
x = 1
if x > 0:
    print('positive')
else:
    print('non-positive')
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "if x > 0 {" in result
    assert "println('positive')" in result
    assert "println('non-positive')" in result

def test_translator_while():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
x = 0
while x < 10:
    x = x + 1
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "for x < 10 {" in result
    assert "x := x + 1" in result

def test_translator_for_range():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
for i in range(10):
    print(i)
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "for i in 0..10 {" in result
    assert "println('${i}')" in result

def test_translator_for_range_start_stop():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
for i in range(1, 10):
    print(i)
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "for i in 1..10 {" in result

def test_translator_break_continue():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
while True:
    if True:
        break
    else:
        continue
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "break" in result
    assert "continue" in result

def test_translator_index_narrowing_loop():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    # We manually register UserDict as a dataclass (TypedDict) for the test
    translator.dataclasses["UserDict"] = ["name", "age"]
    analyzer.type_map["d"] = "UserDict"

    # Simulate mypy inferring Literal for loop key
    analyzer.type_map["key"] = "Literal[\"name\", \"age\"]"

    code = """
for key in ("name", "age"):
    print(d[key])
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "match key {" in result
    assert "'name' { (d.name as Any) }" in result
    assert "'age' { (d.age as Any) }" in result