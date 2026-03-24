import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_type_alias():
    source = """
MyInt = int
UserID = int
MyAlias = OtherClass
var_assign = some_var
"""
    expected_fragments = [
        "type MyInt = int",
        "type UserId = int",
        "type MyAlias = OtherClass",
        "var_assign := some_var"
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"
