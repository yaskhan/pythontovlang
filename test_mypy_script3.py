import os
from mypy.build import build, BuildSource
from mypy.main import process_options
import pprint

def test_mypy():
    source = """
class A:
    def draw(self): pass

def foo(obj: A):
    if hasattr(obj, "draw"):
        obj.draw()
"""
    with open("test_mypy.py", "w") as f:
        f.write(source)

    sources, options = process_options(["test_mypy.py"])
    res = build(sources, options)

    tree = res.files["test_mypy"]

    print(res.types)
    for node, typ in res.types.items():
        print(f"Line {node.line}: {type(node)} -> {typ}")

if __name__ == '__main__':
    sources, options = process_options(["test_mypy.py"])
    res = build(sources, options)
    print(res.files.keys())
    for name, tree in res.files.items():
        if name == 'test_mypy':
            print("Found test_mypy")
            for k, v in res.types.items():
                if k.line > 0 and 'test_mypy' in str(v):
                     print(type(k), v)
