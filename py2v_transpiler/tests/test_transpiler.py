import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_assignment():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = 1"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := 1" in result

def test_translator_function_with_types():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def add(a: int, b: int) -> int:
    return a + b
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "fn add(a int, b int) int {" in result
    assert "return a + b" in result
    assert "}" in result

def test_translator_function_call():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "print('hello')"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "print('hello')" in result

def test_translator_binop():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = 1 + 2 * 3"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := 1 + 2 * 3" in result

def test_translator_return_none():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def foo():
    return
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "return" in result

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
    assert "print('positive')" in result
    assert "} else {" in result
    assert "print('non-positive')" in result

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
    assert "print(i)" in result

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

def test_translator_bool_op():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "if True and False: pass"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "true && false" in result.lower()

def test_translator_unary_op():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "if not True: pass"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "!true" in result.lower()

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

def test_full_module_generation():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def add(a: int, b: int) -> int:
    return a + b

x = 1
y = 2
z = add(x, y)
print(z)
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "module main" in result
    assert "fn add(a int, b int) int {" in result
    assert "fn main() {" in result
    assert "x := 1" in result
    assert "z := add(x, y)" in result

def test_translator_class_def():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
class Point:
    x: int
    y: int

    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y

    def move(self, dx: int, dy: int):
        self.x = self.x + dx
        self.y = self.y + dy
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "struct Point {" in result
    assert "x int" in result
    assert "y int" in result

    # Check factory function for __init__
    assert "fn new_Point(x int, y int) Point {" in result
    assert "self.x := x" in result

    # Check method
    assert "fn (self Point) move(dx int, dy int) {" in result
    assert "self.x := self.x + dx" in result

def test_translator_class_usage():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
p = Point(1, 2)
p.move(3, 4)
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "p := Point(1, 2)" in result
    assert "p.move(3, 4)" in result
