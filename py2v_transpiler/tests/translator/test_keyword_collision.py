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

def test_keyword_collision():
    source = """
class Task:
    def fn(self):
        return 1

    def mut(self, type, struct):
        return type + struct

fn = 1
type = 2
struct = 3
"""
    v_code = translate(source)
    assert "fn (self Task) py_fn()" in v_code
    assert "fn (self Task) py_mut(py_type int, py_struct int)" in v_code
    assert "py_fn := 1" in v_code
    assert "py_type := 2" in v_code
    assert "py_struct := 3" in v_code
