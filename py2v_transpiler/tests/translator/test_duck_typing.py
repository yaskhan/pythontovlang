import ast
import tempfile
import os
import textwrap
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_static_duck_typing_protocol(monkeypatch):
    source = textwrap.dedent("""
from typing import Protocol

class Proto(Protocol):
    def method(self) -> int: ...

class Impl:
    def method(self) -> int: return 42

def call_proto(p: Proto) -> int:
    return p.method()

impl = Impl()
call_proto(impl)
""").strip()

    parser = PyASTParser()
    analyzer = TypeInference()

    original_analyze = analyzer.analyze

    def mock_analyze(tree):
        res = original_analyze(tree)
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and getattr(node.func, "id", "") == "call_proto":
                key = f"{node.lineno}:{node.col_offset}_proto_args"
                analyzer.type_map[key] = {"0": "Proto"}
        return res

    monkeypatch.setattr(analyzer, "analyze", mock_analyze)

    tree = parser.parse(source)
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)

    result = translator.visit_Module(tree)

    assert "interface Proto {" in result
    assert "call_proto(Proto(impl))" in result
