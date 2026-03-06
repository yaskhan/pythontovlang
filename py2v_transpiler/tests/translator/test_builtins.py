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

def test_sorted_builtin():
    source = """
a = [3, 1, 2]
b = sorted(a)
"""
    v_code = translate(source)
    assert "b := py_sorted(a)" in v_code
    assert "fn py_sorted[T](a []T) []T" in v_code

def test_reversed_builtin():
    source = """
a = [1, 2, 3]
b = reversed(a)
"""
    v_code = translate(source)
    assert "b := py_reversed(a)" in v_code
    assert "fn py_reversed[T](a []T) []T" in v_code

def test_sorted_reversed_loop():
    source = """
a = [1, 2]
for x in reversed(sorted(a)):
    pass
"""
    v_code = translate(source)
    assert "for x in py_reversed(py_sorted(a)) {" in v_code
    assert "fn py_sorted" in v_code
    assert "fn py_reversed" in v_code

def test_int_builtin():
    source = """
a = int("123")
b = int(3.14)
c = int()
d = int("ff", 16)
"""
    v_code = translate(source)
    assert "a := '123'.int()" in v_code
    assert "b := int(3.14)" in v_code
    assert "c := 0" in v_code
    assert "d := int(strconv.parse_int('ff', 16, 32) or { 0 })" in v_code

def test_len_builtin():
    source = """
a = [1, 2, 3]
n = len(a)
s = "hello"
l = len(s)
d = {"a": 1}
m = len(d)
"""
    v_code = translate(source)
    assert "n := a.len" in v_code
    assert "l := s.len" in v_code
    assert "m := d.len" in v_code
