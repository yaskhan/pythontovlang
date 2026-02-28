import json

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
res = build(sources, options)

types_dict = res.types

for node, typ in types_dict.items():
    if hasattr(node, 'line') and getattr(node, 'line') > 0:
        if type(node).__name__ == "NameExpr":
            print(f"NameExpr: {node.name}, Line: {node.line}, Col: {node.column}, Type: {typ}")
