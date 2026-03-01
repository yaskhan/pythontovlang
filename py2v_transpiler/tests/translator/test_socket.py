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

def test_socket_creation():
    source = """
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
"""
    v_code = translate(source)
    assert "PySocket" in v_code
    # py_socket_new takes arguments, so the call should be py_socket_new(..., ...)
    assert "py_socket_new(" in v_code

def test_socket_server():
    source = """
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('localhost', 8080))
s.listen(5)
conn, addr = s.accept()
data = conn.recv(1024)
conn.send(data)
conn.close()
"""
    v_code = translate(source)
    # PySocket must handle bind, listen (maybe no-op in V wrapper until accept?), accept
    assert ".bind(" in v_code
    assert ".listen(" in v_code
    assert ".accept()" in v_code
    assert ".recv(" in v_code
    assert ".send(" in v_code
    assert ".close()" in v_code

def test_socket_client():
    source = """
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('localhost', 8080))
s.send(b'hello')
data = s.recv(1024)
s.close()
"""
    v_code = translate(source)
    assert ".connect(" in v_code
    assert ".send(" in v_code
    assert ".recv(" in v_code
