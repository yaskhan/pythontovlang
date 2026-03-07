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

def test_del_list_index():
    source = """
l = [1, 2]
del l[0]
"""
    v_code = translate(source)
    assert "l.delete(0)" in v_code

def test_del_dict_key():
    source = """
d = {"a": 1}
del d["a"]
"""
    v_code = translate(source)
    assert "d.delete('a')" in v_code

def test_del_variable():
    source = """
x = 1
del x
"""
    v_code = translate(source)
    assert "//##LLM@@ 'del x' statement ignored" in v_code

def test_del_attribute():
    source = """
obj.attr = 1
del obj.attr
"""
    v_code = translate(source)
    assert "//##LLM@@ 'del obj.attr' statement ignored" in v_code
