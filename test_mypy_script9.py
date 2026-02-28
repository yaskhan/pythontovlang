from mypy.build import build
from mypy.main import process_options

source = """
from typing import Union

class A:
    def draw(self): pass

class B:
    pass

def foo(obj: Union[A, B]):
    if hasattr(obj, "draw"):
        pass
"""

with open("test_mypy.py", "w") as f:
    f.write(source)

sources, options = process_options(["test_mypy.py"])
options.export_types = True
res = build(sources, options)
tree = res.files["test_mypy"]

def visit(node):
    if hasattr(node, 'line'):
        if node in res.types:
            print(f"Line {node.line}: {type(node)} -> {res.types[node]}")
    if hasattr(node, 'body'):
        for stmt in node.body:
            visit(stmt)

for node in tree.defs:
    visit(node)
