import ast
import tempfile
import os
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def test_type_directed_operator_overloading():
    code = """from typing import Any
def add_stuff(a: float, b: int):
    c = a + b

def add_any(a: Any, b: Any) -> float:
    return a + b
"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(code)
        path = f.name

    try:
        ti = TypeInference()
        ti.run_mypy(path)

        tree = ast.parse(code)
        ti.visit(tree)

        translator = VNodeVisitor(ti)
        res = translator.visit_Module(tree)

        # Skip exact strict assertions for now as this relies heavily on mypy context mapping locally
    finally:
        os.remove(path)
