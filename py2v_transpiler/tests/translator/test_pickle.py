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

def test_pickle_dumps():
    source = """
import pickle
data = {'a': 1}
s = pickle.dumps(data)
"""
    v_code = translate(source)
    # We map pickle to json as best effort
    assert "import json" in v_code
    assert "s := py_pickle_dumps(data)" in v_code

def test_pickle_loads():
    source = """
import pickle
s = '{"a": 1}'
data = pickle.loads(s)
"""
    v_code = translate(source)
    assert "import json" in v_code
    assert "data := py_pickle_loads(s)" in v_code
