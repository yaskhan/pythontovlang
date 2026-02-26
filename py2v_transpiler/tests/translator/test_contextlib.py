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

def test_contextlib_suppress():
    source = """
import contextlib
with contextlib.suppress(Exception):
    print("hello")
"""
    # This assumes 'visit_With' can handle contextlib.suppress or mapped to generic 'try/catch' equivalent?
    # V doesn't have try/catch blocks.
    # If mapped to nothing (ignored), that's valid for transpilation prototype.
    # Or mapped to a comment?
    v_code = translate(source)
    # We expect the body to be preserved.
    assert 'println(\'hello\')' in v_code
    # Ideally, we see some error handling artifact or just the body if suppress is best-effort.
    # But `visit_With` usually generates `x := mgr; defer x.close(); body`.
    # `suppress` returns a context manager.
    # If we map `contextlib.suppress` to `py_suppress`, it returns a struct with `close`?
    # `suppress` in Python handles exceptions in `__exit__`.
    # V `defer` doesn't catch panics/errors from body.
    # So `suppress` is hard to map perfectly.
    # Let's see what happens.

def test_contextlib_closing():
    source = """
import contextlib
class A:
    def close(self): pass

with contextlib.closing(A()) as a:
    pass
"""
    v_code = translate(source)
    # This should work with standard `visit_With` if `closing` returns something with `.close()`.
    # `closing(thing)` returns `thing` (mostly).
    # If we map `contextlib.closing(x)` to `x`, `visit_With` will call `x.close()` (mapped from `__exit__` logic?
    # Actually `visit_With` in this project assumes the context manager expression returns a resource, and calls `.close()` on it?
    # Let's check `visit_With` logic later.
    pass
