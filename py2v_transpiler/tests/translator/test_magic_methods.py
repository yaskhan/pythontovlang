import ast
from typing import cast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.parser import PyASTParser

def transpile(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(cast(ast.Module, tree))

def test_magic_methods_len_and_getitem():
    code = """
class Plan:
    def __init__(self, constraints: list[int]):
        self.constraints = constraints

    def __len__(self) -> int:
        return len(self.constraints)

    def __getitem__(self, index: int) -> int:
        return self.constraints[index]
"""
    v_code = transpile(code)

    assert "fn (self Plan) len() int {" in v_code
    assert "fn (self Plan) idx(index int) int {" in v_code

def test_magic_methods_outside_class():
    code = """
def __len__(self) -> int:
    return 1

def __getitem__(self, index: int) -> int:
    return index
"""
    v_code = transpile(code)

    assert "fn len(self int) int {" in v_code
    assert "fn idx(self int, index int) int {" in v_code
