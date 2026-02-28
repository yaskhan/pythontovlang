import ast
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
options.preserve_asts = True
options.check_untyped_defs = True
res = build(sources, options)

for node, typ in res.types.items():
    if hasattr(node, 'line') and getattr(node, 'line') > 0 and 'test_mypy' in str(node):
        print(type(node).__name__, node.line, typ)
