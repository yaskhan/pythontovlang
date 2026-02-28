import sys
import ast
from mypy.build import build
from mypy.main import process_options
from mypy.types import Instance, UnionType

class ASTTypeMatcher:
    def __init__(self, mypy_types):
        self.mypy_types = mypy_types
        # We index mypy types by (line, col_offset)
        self.node_types = {}
        for node, typ in mypy_types.items():
            if hasattr(node, "line") and hasattr(node, "column"):
                self.node_types[(node.line, node.column)] = typ

    def get_type(self, ast_node):
        return self.node_types.get((ast_node.lineno, ast_node.col_offset))

source = """
from typing import Union

class A:
    def draw(self): pass

class B:
    pass

def foo(obj: Union[A, B], obj2: A):
    if hasattr(obj, "draw"):
        pass
    if hasattr(obj2, "draw"):
        pass
    if hasattr(obj, "other"):
        pass
"""

with open("test_mypy.py", "w") as f:
    f.write(source)

sources, options = process_options(["test_mypy.py"])
options.export_types = True
options.preserve_asts = True
options.check_untyped_defs = True
res = build(sources, options)

matcher = ASTTypeMatcher(res.types)
tree = ast.parse(source)

class Visitor(ast.NodeVisitor):
    def visit_Call(self, node):
        if isinstance(node.func, ast.Name) and node.func.id == "hasattr":
            obj_node = node.args[0]
            attr_node = node.args[1]
            typ = matcher.get_type(obj_node)
            print(f"hasattr on line {node.lineno}: obj type = {typ}")
        self.generic_visit(node)

Visitor().visit(tree)
