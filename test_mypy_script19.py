from mypy.build import build
from mypy.main import process_options

def test_mypy_type_checking():
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
"""

    with open("test_mypy.py", "w") as f:
        f.write(source)

    sources, options = process_options(["test_mypy.py"])
    options.export_types = True
    options.preserve_asts = True
    options.check_untyped_defs = True
    res = build(sources, options)

    line_to_type = {}
    for node, typ in res.types.items():
        if getattr(node, "line", -1) > 0:
            if type(node).__name__ == "NameExpr" and "obj" in node.name:
                line_to_type[(node.line, node.name)] = typ

    print(line_to_type)

test_mypy_type_checking()
