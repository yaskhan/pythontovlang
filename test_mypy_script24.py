import ast

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

from mypy.build import build
from mypy.main import process_options

sources, options = process_options(["test_mypy.py"])
options.export_types = True
options.preserve_asts = True
options.check_untyped_defs = True
res = build(sources, options)

for node, typ in res.types.items():
    if hasattr(node, 'line') and getattr(node, 'line') > 0:
        if hasattr(node, 'name') and node.name.startswith("obj"):
            print(f"MYPY Line {node.line}, Col {node.column}, Name {node.name}, Type {typ}")

for node in ast.walk(ast.parse(source)):
    if isinstance(node, ast.Name) and node.id.startswith("obj"):
        print(f"AST Line {node.lineno}, Col {node.col_offset}, Name {node.id}")
