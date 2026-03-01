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

def test_threading_lock():
    source = """
import threading
l = threading.Lock()
l.acquire()
l.release()
"""
    v_code = translate(source)
    # V sync.Mutex has .lock() and .unlock()
    assert "sync.new_mutex()" in v_code
    assert ".lock()" in v_code
    assert ".unlock()" in v_code

def test_threading_thread_start_join():
    source = """
import threading
def worker():
    pass
t = threading.Thread(target=worker)
t.start()
t.join()
"""
    v_code = translate(source)
    # We might map Thread to a helper, start() to spawn, join() to wait().
    # Or map Thread directly if we can't fully emulate deferral.
    # For now, let's assume we implement a PyThread struct pattern.
    assert "PyThread" in v_code
    assert ".start()" in v_code
    assert ".join()" in v_code
