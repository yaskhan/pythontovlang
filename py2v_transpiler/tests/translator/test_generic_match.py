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
    return v_code

def test_generic_match_basic():
    source = """
match x:
    case Box[int](value=v):
        pass
"""
    v_code = translate(source)
    assert "is Box[int]" in v_code
    assert "as Box[int]" in v_code

def test_generic_match_nested():
    source = """
match x:
    case Container[Box[str]](inner=b):
        pass
"""
    v_code = translate(source)
    assert "is Container[Box[string]]" in v_code
    assert "as Container[Box[string]]" in v_code

def test_generic_match_multiple_args():
    source = """
match x:
    case Pair[int, str](first=f, second=s):
        pass
"""
    v_code = translate(source)
    assert "is Pair[int, string]" in v_code
    assert "as Pair[int, string]" in v_code

def test_generic_match_as_narrowing():
    source = """
match x:
    case Box[float](value=v) as b:
        pass
"""
    v_code = translate(source)
    assert "b := (_match_subject_any_1 as Box[f64])" in v_code
    # Wait, float maps to f64 in MatchClass, but let's check _unmangle_generic_name doesn't interfere.
    # In my verify_generics it showed Box[int] which is correct because int maps to int.
    # float should map to f64.

def test_generic_match_with_guard():
    source = """
match x:
    case Box[int](value=v) if v > 0:
        pass
"""
    v_code = translate(source)
    assert "is Box[int]" in v_code
    assert "if (v > 0) {" in v_code

def test_generic_match_deeply_nested():
    source = """
match x:
    case A[B[C[D]]](val=v):
        pass
"""
    v_code = translate(source)
    assert "is A[B[C[D]]]" in v_code
