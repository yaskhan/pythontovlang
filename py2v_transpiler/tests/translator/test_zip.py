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

def test_zip_for_loop():
    source = """
a = [1, 2]
b = [3, 4]
for x, y in zip(a, b):
    print(x + y)
"""
    v_code = translate(source)
    # Check for unique variable naming pattern
    assert "py_zip_it1_1 := a" in v_code
    assert "py_zip_it2_1 := b" in v_code
    assert "for py_i_1, py_v1_1 in py_zip_it1_1 {" in v_code
    assert "if py_i_1 >= py_zip_it2_1.len { break }" in v_code
    assert "py_v2_1 := py_zip_it2_1[py_i_1]" in v_code
    assert "x := py_v1_1" in v_code
    assert "y := py_v2_1" in v_code

def test_zip_list_comp():
    source = """
a = [1, 2]
b = [3, 4]
sums = [x + y for x, y in zip(a, b)]
"""
    v_code = translate(source)
    assert "mut sums := []int{}" in v_code
    # Assuming this is the first zip call in the translator instance for this test
    # But wait, translate() creates a NEW translator instance each time.
    # So counter resets to 0, then increments to 1.
    assert "py_zip_it1_1 := a" in v_code
    assert "sums << x + y" in v_code

def test_zip_single_target():
    source = """
a = [1, 2]
b = [3, 4]
for t in zip(a, b):
    print(t)
"""
    v_code = translate(source)
    assert "t := [py_v1_1, py_v2_1]" in v_code

def test_zip_multiple_usage_collision():
    source = """
a = [1]
b = [2]
for x, y in zip(a, b):
    pass
for x, y in zip(a, b):
    pass
"""
    v_code = translate(source)
    # First loop
    assert "py_zip_it1_1 := a" in v_code
    # Second loop should have different suffix
    assert "py_zip_it1_2 := a" in v_code
    # Ensure no collision in variable declarations (not rigorous, but checks presence)
    assert "for py_i_1, py_v1_1 in py_zip_it1_1 {" in v_code
    assert "for py_i_2, py_v1_2 in py_zip_it1_2 {" in v_code
