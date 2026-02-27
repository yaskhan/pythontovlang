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
        "(y is int || y is float)"
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"
