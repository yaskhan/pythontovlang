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

def test_uuid4():
    source = """
import uuid
u = uuid.uuid4()
print(u)
"""
    v_code = translate(source)
    assert "u := rand.uuid_v4()" in v_code
    assert "import rand" in v_code

def test_uuid4_str():
    source = """
import uuid
u = str(uuid.uuid4())
"""
    v_code = translate(source)
    assert "u := str(rand.uuid_v4())" in v_code # V's uuid_v4 returns string usually, so str() might be redundant but valid.
