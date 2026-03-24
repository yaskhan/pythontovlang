from .utils import translate_with_mypy
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
import ast
from typing import cast

def translate_with_mypy_v2(code: str, parser: PyASTParser, type_inference: TypeInference) -> str:
    """Helper to translate code with Mypy analysis using a temporary file."""
    import tempfile, os
    from py2v_transpiler.core.translator import VNodeVisitor

    tree = parser.parse(code)

    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        f.write(code)
        temp_path = f.name

    try:
        type_inference.analyze(tree)
        type_inference.run_mypy(temp_path)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    visitor = VNodeVisitor(type_inference)
    visitor.visit(tree)
    return visitor.emitter.emit()

def test_optional_none_comparison():
    parser = PyASTParser()
    type_inference = TypeInference()
    code = """
from typing import Optional

class Packet:
    def __init__(self, d: int):
        self.datum = d

class Task:
    def __init__(self, p: Optional[Packet] = None):
        self.work_in = p

def run():
    h = Task()
    work = h.work_in
    if work is None:
        return
    print(work.datum)
"""
    v_code = translate_with_mypy_v2(code, parser, type_inference)
    # The bug is that it generates "if (work) is NoneType {" instead of "if work == none {"
    assert "if (work) is NoneType" not in v_code
    assert "work == none" in v_code

def test_any_none_comparison():
    parser = PyASTParser()
    type_inference = TypeInference()
    # For Any (sum type), it SHOULD use 'is NoneType'
    code = """
from typing import Any
def run(work: Any):
    if work is None:
        return
    print(work)
"""
    v_code = translate_with_mypy_v2(code, parser, type_inference)
    assert "is NoneType" in v_code

def test_unknown_none_comparison():
    parser = PyASTParser()
    type_inference = TypeInference()
    # For unknown type, it SHOULD use '== none' as it is likely an Optional
    code = """
def run(h):
    work = h.work_in
    if work is None:
        return
    print(work)
"""
    v_code = translate_with_mypy_v2(code, parser, type_inference)
    assert "is NoneType" not in v_code
    assert "work == none" in v_code

def test_sumtype_none_comparison():
    parser = PyASTParser()
    type_inference = TypeInference()
    code = """
from typing import Union
class A: pass
class B: pass
def run(work: Union[A, B, None]):
    if work is None:
        return
    print(work)
"""
    v_code = translate_with_mypy_v2(code, parser, type_inference)
    # Union[A, B, None] maps to ?SumType_AB.
    # Optional SumType should use == none.
    assert "work == none" in v_code
    assert "is NoneType" not in v_code
