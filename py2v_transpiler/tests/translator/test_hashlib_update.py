import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    return v_code

def test_hashlib_update_not_dict_update():
    source = """
import hashlib
h = hashlib.sha256()
h.update(b'foo')
"""
    v_code = translate(source)
    # Should stay as .update(b'foo') and NOT become py_dict_update(mut h, b'foo')
    assert "h.update" in v_code
    assert "py_dict_update" not in v_code

def test_dict_update_works():
    source = """
d = {}
d.update({"a": 1})
"""
    v_code = translate(source)
    assert "py_dict_update" in v_code
