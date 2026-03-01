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

def test_contextlib_suppress():
    source = """
import contextlib
with contextlib.suppress(Exception):
    print("hello")
"""
    v_code = translate(source)
    # The suppress call should be emitted as a comment, and the body should be emitted
    assert "/* contextlib.suppress(Exception) */" in v_code
    assert "println('hello')" in v_code
    # Should NOT contain defer
    assert "defer" not in v_code

def test_contextlib_nullcontext():
    source = """
from contextlib import nullcontext
with nullcontext(1) as x:
    print(x)
"""
    v_code = translate(source)
    # nullcontext(1) maps to 1
    # x := 1
    # print(x)
    assert "x := 1" in v_code
    assert "println('${x}')" in v_code
    # Should NOT contain defer
    assert "defer" not in v_code

def test_contextlib_closing():
    source = """
from contextlib import closing
with closing(open("file.txt")) as f:
    pass
"""
    v_code = translate(source)
    # closing(x) maps to x
    # f := os.open(...)
    # defer { f.close() }
    assert "os.open" in v_code
    assert "defer { f.close() }" in v_code

def test_contextlib_redirect_stdout():
    source = """
import contextlib
import io
f = io.StringIO()
with contextlib.redirect_stdout(f):
    print('foobar')
"""
    v_code = translate(source)
    # redirect_stdout is ignored (comment)
    assert "/* contextlib.redirect_stdout(f) ignored */" in v_code
    assert "println('foobar')" in v_code
