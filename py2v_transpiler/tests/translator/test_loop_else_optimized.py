import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    return v_code

def test_while_else_no_break():
    source = """
i = 0
while i < 3:
    i += 1
else:
    print("Done")
"""
    v_code = translate(source)
    assert "py_loop_completed" not in v_code
    assert "println('Done')" in v_code

def test_while_else_with_break():
    source = """
i = 0
while i < 3:
    if i == 1: break
    i += 1
else:
    print("Done")
"""
    v_code = translate(source)
    assert "mut py_loop_completed" in v_code
    assert "if py_loop_completed" in v_code

def test_for_else_no_break():
    source = """
for i in range(3):
    print(i)
else:
    print("Done")
"""
    v_code = translate(source)
    assert "py_loop_completed" not in v_code
    assert "println('Done')" in v_code

def test_for_else_with_break():
    source = """
for i in range(3):
    if i == 1: break
else:
    print("Done")
"""
    v_code = translate(source)
    assert "mut py_loop_completed" in v_code
    assert "if py_loop_completed" in v_code

def test_print_end_tab():
    source = 'print("A", end="\\t")'
    v_code = translate(source)
    assert "print('A\\t')" in v_code

def test_print_dynamic_sep_end():
    source = """
s = "-"
e = "!"
x = 10
print(x, "B", sep=s, end=e)
"""
    v_code = translate(source)
    assert ".join(s)" in v_code
    assert "${e}" in v_code

def test_loop_match_break():
    source = """
for i in range(5):
    match i:
        case 2: break
else:
    print("Done")
"""
    v_code = translate(source)
    assert "mut py_loop_completed" in v_code
