import ast
import sys
import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

@pytest.mark.skipif(sys.version_info < (3, 10), reason="requires python3.10 or higher")
def test_match_literal():
    source = """
match x:
    case 1:
        print("one")
    case 2:
        print("two")
    case "str":
        print("string")
    case _:
        print("other")
"""
    expected_fragments = [
        "match x {",
        "1 {",
        "println('one')",
        "2 {",
        "println('two')",
        "'str' {",
        "println('string')",
        "else {",
        "println('other')"
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)
    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"

@pytest.mark.skipif(sys.version_info < (3, 10), reason="requires python3.10 or higher")
def test_match_or_pattern():
    source = """
match x:
    case 1 | 2:
        print("one or two")
"""
    expected_fragments = [
        "match x {",
        "1, 2 {",
        "println('one or two')"
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)
    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"
