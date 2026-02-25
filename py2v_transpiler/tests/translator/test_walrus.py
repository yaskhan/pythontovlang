import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_walrus_if():
    source = """
if (x := 5) > 0:
    print(x)
"""
    expected_fragments = [
        "x := 5",
        "if x > 0 {",
        "println('${x}')" # Expecting interpolation for var in println
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"

def test_walrus_while():
    source = """
while (x := input()) != 'exit':
    print(x)
"""
    # V does not support assignment in condition directly in the same way.
    # Idiomatic V for `while (x := expr)` is `for { x := expr; if !cond { break } ... }`
    expected_fragments = [
        "for {",
        "x := os.input('')",
        "if !(x != 'exit') { break }",
        "println('${x}')" # Expecting interpolation for var in println
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"
