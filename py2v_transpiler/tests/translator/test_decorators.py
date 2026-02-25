import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_decorators():
    source = """
@my_decorator
def my_func():
    pass

@decorator1
@decorator2(args)
class MyClass:
    pass
"""
    expected_fragments = [
        "// @my_decorator",
        "fn my_func() {",
        "// @decorator1",
        "// @decorator2(args)",
        "struct MyClass {"
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print(code) # For debugging if needed

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"
