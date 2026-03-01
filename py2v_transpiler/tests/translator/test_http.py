import ast
import pytest
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

def test_urllib_request_urlopen():
    source = """
import urllib.request
response = urllib.request.urlopen('http://example.com')
content = response.read()
"""
    v_code = translate(source)
    assert "py_urlopen" in v_code
    assert "read()" in v_code

def test_http_client_connection():
    source = """
import http.client
conn = http.client.HTTPConnection("example.com")
conn.request("GET", "/")
resp = conn.getresponse()
data = resp.read()
"""
    v_code = translate(source)
    # This is more complex. http.client usage maps poorly to simple http.get.
    # Maybe map to a helper or just partial support.
    # If we map HTTPConnection to a struct that wraps net.http logic?
    # For now, let's see if we can just support basic structure.
    assert "HTTPConnection" in v_code or "py_http_connection" in v_code
