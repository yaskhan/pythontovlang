import sys
import ast
import traceback
from typing import Dict, Any, Tuple, Optional
from mypy.build import build
from mypy.main import process_options
from mypy.types import Instance, UnionType

class ASTTypeMatcher:
    def __init__(self, mypy_types):
        self.node_types = {}
        for node, typ in mypy_types.items():
            if hasattr(node, "line") and hasattr(node, "column"):
                self.node_types[(node.line, node.column)] = typ

    def get_type(self, ast_node):
        return self.node_types.get((ast_node.lineno, ast_node.col_offset))

    def has_readable_member(self, typ, attr_name):
        if typ is None:
            return "unknown"

        if isinstance(typ, Instance):
            if attr_name in typ.type.names:
                return True
            for base in typ.type.mro:
                if attr_name in base.names:
                    return True
            return False
        elif isinstance(typ, UnionType):
            results = [self.has_readable_member(item, attr_name) for item in typ.items]
            # Remove "unknown" results for the purpose of checking if it definitely has or doesn't have it
            valid_results = [r for r in results if isinstance(r, bool)]
            if not valid_results:
                return "unknown"
            if all(valid_results):
                return True
            if not any(valid_results):
                return False
            return "mixed"
        return "unknown"

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
            if isinstance(attr_node, ast.Constant) and isinstance(attr_node.value, str):
                attr_name = attr_node.value
                typ = matcher.get_type(obj_node)
                has_member = matcher.has_readable_member(typ, attr_name)
                print(f"hasattr on line {node.lineno}: obj type = {typ} -> {has_member}")
        self.generic_visit(node)

Visitor().visit(tree)
