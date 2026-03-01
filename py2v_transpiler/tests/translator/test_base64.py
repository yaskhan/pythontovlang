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
    return translator.visit_Module(tree)

def test_base64_b64encode():
    source = """
import base64
encoded = base64.b64encode(b'hello')
"""
    v_code = translate(source)
    assert "import encoding.base64" in v_code
    assert "encoded := base64.encode(" in v_code

def test_base64_b64decode():
    source = """
import base64
decoded = base64.b64decode('aGVsbG8=')
"""
    v_code = translate(source)
    assert "import encoding.base64" in v_code
    assert "decoded := base64.decode(" in v_code

def test_base64_standard_b64encode():
    source = """
import base64
encoded = base64.standard_b64encode(b'hello')
"""
    v_code = translate(source)
    assert "import encoding.base64" in v_code
    assert "encoded := base64.encode(" in v_code

def test_base64_standard_b64decode():
    source = """
import base64
decoded = base64.standard_b64decode('aGVsbG8=')
"""
    v_code = translate(source)
    assert "import encoding.base64" in v_code
    assert "decoded := base64.decode(" in v_code

def test_base64_urlsafe_b64encode():
    source = """
import base64
encoded = base64.urlsafe_b64encode(b'hello')
"""
    v_code = translate(source)
    assert "import encoding.base64" in v_code
    assert "encoded := base64.url_encode(" in v_code

def test_base64_urlsafe_b64decode():
    source = """
import base64
decoded = base64.urlsafe_b64decode('aGVsbG8=')
"""
    v_code = translate(source)
    assert "import encoding.base64" in v_code
    assert "decoded := base64.url_decode(" in v_code
