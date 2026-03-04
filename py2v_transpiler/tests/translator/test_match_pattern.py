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

def test_match_guard():
    source = """
x = 10
match x:
    case 1 if x > 0:
        pass
"""
    v_code = translate(source)
    # New refactored structure uses separate if blocks with _match_found flag
    assert "_match_found_1" in v_code
    assert "if !_match_found_1 && (_match_subject_any_1 == 1) {" in v_code
    assert "if (x > 0) {" in v_code

def test_match_sequence():
    source = """
x = [1, 2]
match x:
    case [1, 2]:
        pass
"""
    v_code = translate(source)
    # Expect array type checks
    assert "is []int" in v_code

def test_match_sequence_rest():
    source = """
x = [1, 2, 3]
match x:
    case [a, *rest, b]:
        pass
"""
    v_code = translate(source)
    # Expect indexing from end logic
    # ".len -" implies `len - offset`
    assert ".len -" in v_code
    # Check rest slicing
    assert ".." in v_code

def test_match_mapping():
    source = """
x = {'a': 1}
match x:
    case {'a': 1}:
        pass
"""
    v_code = translate(source)
    # Expect map type checks
    assert "is map[string]int" in v_code

def test_match_or():
    source = """
x = 1
match x:
    case 1 | 2:
        pass
"""
    v_code = translate(source)
    # Expect separate checks (split cases)
    assert "== 1" in v_code
    assert "== 2" in v_code

def test_match_capture():
    source = """
x = 10
match x:
    case y:
        pass
"""
    v_code = translate(source)
    # Expect variable binding
    assert "y :=" in v_code

def test_match_value():
    source = """
x = 10
match x:
    case 10:
        pass
"""
    v_code = translate(source)
    assert "== 10" in v_code

def test_match_wildcard():
    source = """
x = 10
match x:
    case _:
        pass
"""
    v_code = translate(source)
    # New structure uses separate if blocks
    assert "if !_match_found_1 {" in v_code

def test_match_class():
    source = """
class Point:
    pass
x = Point()
match x:
    case Point(x=1):
        pass
"""
    v_code = translate(source)
    assert "is Point" in v_code
