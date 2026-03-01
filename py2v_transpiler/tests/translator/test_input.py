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

def test_input_no_arg():
    source = "x = input()"
    v_code = translate(source)
    assert "import os" in v_code
    assert "x := os.input('')" in v_code

def test_input_with_prompt():
    source = "x = input('Name: ')"
    v_code = translate(source)
    assert "import os" in v_code
    assert "x := os.input('Name: ')" in v_code
