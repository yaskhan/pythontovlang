import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile(code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)  # type: ignore[arg-type]

def test_none_initialization_untyped():
    code = "planner = None"
    v_code = transpile(code)
    # the analyzer falls back to 'Any' (formerly 'int') in _guess_type
    assert "mut planner := (none as ?Any)" in v_code

def test_none_initialization_typed():
    code = "planner: Planner = None"
    v_code = transpile(code)
    assert "mut planner := (none as ?Planner)" in v_code

def test_none_initialization_optional():
    code = "planner: Optional[int] = None"
    v_code = transpile(code)
    assert "mut planner := (none as ?int)" in v_code

def test_none_initialization_optional_forward_ref():
    code = "planner: Optional['Packet'] = None"
    v_code = transpile(code)
    assert "mut planner := (none as ?Packet)" in v_code
