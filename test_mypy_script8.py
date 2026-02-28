from mypy.nodes import SymbolTableNode, TypeInfo
from mypy.build import build, BuildSource
from mypy.main import process_options

source = """
class A:
    def draw(self): pass

class B:
    pass

def foo(obj: A):
    if hasattr(obj, "draw"):
        pass
"""

with open("test_mypy.py", "w") as f:
    f.write(source)

sources, options = process_options(["test_mypy.py"])
res = build(sources, options)

# We can find TypeInfo in tree.names
tree = res.files["test_mypy"]
for name, symbol in tree.names.items():
    if isinstance(symbol.node, TypeInfo):
        print(f"Class {name}")
        for attr_name, attr_symbol in symbol.node.names.items():
            print(f"  - attr: {attr_name}")

# Now, we also need to know the type of `obj` inside `foo`.
# We can traverse the AST mypy built.
for name, symbol in tree.names.items():
    if name == 'foo':
        func_def = symbol.node
        print(f"Func {name}: {func_def.type}")
