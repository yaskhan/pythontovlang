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
options.check_untyped_defs = True
options.preserve_asts = True
res = build(sources, options)
tree = res.files["test_mypy"]

print(f"Number of types: {len(res.types)}")
for node, typ in res.types.items():
    if getattr(node, 'line', -1) > 0 and 'test_mypy' in str(node):
        print(f"Line {node.line}: {type(node)} -> {typ} | code: {node}")
