import pytest
from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
from py2v_transpiler.core.translator.base import TranslatorBase
from py2v_transpiler.core.analyzer import TypeInference
import ast

class DummyTranslator(ExpressionsMixin, LiteralsMixin, TranslatorBase):
    def __init__(self):
        type_inference = TypeInference()
        super().__init__(type_inference)
        self.output = []
        self._indent_level = 0
        self.unique_id_counter = 0

    def visit(self, node):
        if isinstance(node, ast.Name):
            return node.id
        elif isinstance(node, ast.Constant):
            return str(node.value)
        elif isinstance(node, ast.List):
            return f"[{', '.join(str(x.value) for x in node.elts)}]"
        elif isinstance(node, ast.Tuple):
            return f"[{', '.join(str(x.value) for x in node.elts)}]"
        elif isinstance(node, ast.Call):
            args_str = []
            for x in node.args:
                if isinstance(x, ast.Constant):
                    args_str.append(str(x.value))
                elif isinstance(x, ast.UnaryOp):
                    args_str.append(f"-{x.operand.value}")
                else:
                    args_str.append(x.id)
            return f"{node.func.id}({', '.join(args_str)})"
        elif isinstance(node, ast.BinOp):
            return f"{self.visit(node.left)} {type(node.op).__name__} {self.visit(node.right)}"
        elif isinstance(node, ast.UnaryOp):
            if isinstance(node.op, ast.USub):
                return f"-{node.operand.value}"
        return super().visit(node)

def test_list_comp_prealloc_range_1_arg():
    code = "[i for i in range(10)]"
    node = ast.parse(code).body[0].value
    trans = DummyTranslator()
    trans.visit_ListComp(node, target_var="res")
    v_code = "\n".join(trans.output)
    assert "mut res := []int{cap: 10}" in v_code
    assert "for i in 0..10 {" in v_code

def test_list_comp_prealloc_range_2_args():
    code = "[i for i in range(5, 10)]"
    node = ast.parse(code).body[0].value
    trans = DummyTranslator()
    trans.visit_ListComp(node, target_var="res")
    v_code = "\n".join(trans.output)
    assert "mut res := []int{cap: 5}" in v_code
    assert "for i in 5..10 {" in v_code

def test_list_comp_prealloc_range_3_args():
    code = "[i for i in range(1, 10, 2)]"
    node = ast.parse(code).body[0].value
    trans = DummyTranslator()
    trans.visit_ListComp(node, target_var="res")
    v_code = "\n".join(trans.output)
    assert "mut res := []int{cap: 5}" in v_code
    assert "for i := 1; i < 10; i += 2 {" in v_code

def test_list_comp_prealloc_range_negative_step():
    code = "[i for i in range(10, 1, -2)]"
    node = ast.parse(code).body[0].value
    trans = DummyTranslator()
    trans.visit_ListComp(node, target_var="res")
    v_code = "\n".join(trans.output)
    assert "mut res := []int{cap: 5}" in v_code
    assert "for i := 10; i > 1; i += -2 {" in v_code

def test_list_comp_prealloc_list_literal():
    code = "[i for i in [1, 2, 3, 4]]"
    node = ast.parse(code).body[0].value
    trans = DummyTranslator()
    trans.visit_ListComp(node, target_var="res")
    v_code = "\n".join(trans.output)
    assert "mut res := []int{cap: 4}" in v_code

def test_list_comp_prealloc_tuple_literal():
    code = "[i for i in (1, 2, 3)]"
    node = ast.parse(code).body[0].value
    trans = DummyTranslator()
    trans.visit_ListComp(node, target_var="res")
    v_code = "\n".join(trans.output)
    assert "mut res := []int{cap: 3}" in v_code

def test_list_comp_no_prealloc_with_ifs():
    code = "[i for i in range(10) if i > 2]"
    node = ast.parse(code).body[0].value
    trans = DummyTranslator()
    trans.visit_ListComp(node, target_var="res")
    v_code = "\n".join(trans.output)
    assert "mut res := []int{}" in v_code
    assert "cap:" not in v_code
