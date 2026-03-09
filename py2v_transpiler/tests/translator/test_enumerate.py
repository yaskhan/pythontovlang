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

def test_enumerate_for_loop():
    source = """
items = [1, 2, 3]
for i, item in enumerate(items):
    print(f"{i}: {item}")
"""
    v_code = translate(source)
    assert "items := [1, 2, 3]" in v_code
    assert "for i, item in items {" in v_code

def test_enumerate_single_target():
    source = """
items = ["a", "b"]
for x in enumerate(items):
    pass
"""
    v_code = translate(source)
    assert "//##LLM@@ Enumerate used with a single target variable instead of unpacking. Please rewrite to unpack the index and value properly." in v_code
    assert "for x in items {" in v_code

def test_enumerate_list_comp():
    source = """
items = ["a", "b"]
indices = [i for i, x in enumerate(items)]
"""
    v_code = translate(source)
    # This expects visit_ListComp to handle enumerate
    # Currently it likely produces `for [i, x] in enumerate(items)` or similar
    assert "for i, x in items {" in v_code
