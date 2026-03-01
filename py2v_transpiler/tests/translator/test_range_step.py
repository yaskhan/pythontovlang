import ast
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

def test_range_positive_step():
    source = """
for i in range(0, 10, 2):
    print(i)
"""
    v_code = translate(source)
    assert "for i := 0; i < 10; i += 2 {" in v_code

def test_range_negative_step_literal():
    source = """
for i in range(10, 0, -1):
    print(i)
"""
    v_code = translate(source)
    # Check for negative step condition (> 0) and increment (-1)
    assert "for i := 10; i > 0; i += -1 {" in v_code

def test_range_negative_step_unary():
    source = """
step = 1
for i in range(10, 0, -step):
    print(i)
"""
    v_code = translate(source)
    # This might fail my naive check if step is a variable, but here it's UnaryOp(-step)
    # My implementation checks for UnaryOp(USub) on the step node.
    assert "for i := 10; i > 0; i += -step {" in v_code

def test_list_comp_step():
    source = """
squares = [x*x for x in range(0, 10, 2)]
"""
    v_code = translate(source)
    assert "mut squares := []int{cap: 5}" in v_code
    assert "for x := 0; x < 10; x += 2 {" in v_code
    assert "squares << x * x" in v_code
