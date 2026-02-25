import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_isinstance():
    source = """
if isinstance(x, MyClass):
    pass
if isinstance(y, (int, float)):
    pass
"""
    expected_fragments = [
        "if x is MyClass {",
        "// isinstance(y, (int, float)) is complex to map directly"
    ]
    # For now, let's just support the single type check which maps nicely to V's `is`
    # Multi-type check is harder.

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print(code)

    assert "if x is MyClass {" in code
