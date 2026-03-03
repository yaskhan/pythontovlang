import ast
from py2v_transpiler.core.translator import TranslatorBase, ControlFlowMixin
from py2v_transpiler.core.generator import VCodeEmitter
from typing import Any

class DummyTypeInference:
    def __init__(self, mapping):
        self.type_map = mapping
        self.location_map = {}

    def resolve_type(self, node):
        if isinstance(node, ast.Name) and node.id in self.type_map:
            return self.type_map[node.id]
        return "void"

class DummyTranslator(ControlFlowMixin):
    def __init__(self, mapping):
        super().__init__(DummyTypeInference(mapping))
        self.emitter = VCodeEmitter()

    def visit(self, node):
        if isinstance(node, ast.Name):
            return node.id
        elif isinstance(node, ast.Constant):
            return str(node.value).lower() if isinstance(node.value, bool) else str(node.value)
        return super().visit(node)

def test_while_queue_truth_value():
    # while queue:
    node = ast.While(
        test=ast.Name(id="queue", ctx=ast.Load()),
        body=[ast.Expr(value=ast.Constant(value=1))],
        orelse=[]
    )

    translator = DummyTranslator({"queue": "[]int"})
    translator.visit_While(node)

    v_code = "\n".join(translator.output)

    assert "for queue.len > 0 {" in v_code

def test_while_dict_truth_value():
    node = ast.While(
        test=ast.Name(id="my_dict", ctx=ast.Load()),
        body=[ast.Expr(value=ast.Constant(value=1))],
        orelse=[]
    )

    translator = DummyTranslator({"my_dict": "map[string]int"})
    translator.visit_While(node)

    v_code = "\n".join(translator.output)

    assert "for my_dict.len > 0 {" in v_code

def test_while_string_truth_value():
    node = ast.While(
        test=ast.Name(id="s", ctx=ast.Load()),
        body=[ast.Expr(value=ast.Constant(value=1))],
        orelse=[]
    )

    translator = DummyTranslator({"s": "string"})
    translator.visit_While(node)

    v_code = "\n".join(translator.output)

    assert "for s.len > 0 {" in v_code

def test_while_bool_unchanged():
    node = ast.While(
        test=ast.Name(id="is_active", ctx=ast.Load()),
        body=[ast.Expr(value=ast.Constant(value=1))],
        orelse=[]
    )

    translator = DummyTranslator({"is_active": "bool"})
    translator.visit_While(node)

    v_code = "\n".join(translator.output)

    assert "for is_active {" in v_code
