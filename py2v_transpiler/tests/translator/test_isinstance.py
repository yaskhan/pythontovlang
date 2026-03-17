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

def test_isinstance_with_name_collision():
    source = """
class Dog:
    pass

def test():
    dog = Dog()
    if isinstance(dog, Dog):
        print("is a dog")
"""
    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    # Dog (type) should NOT be snake-cased to dog (variable)
    assert "if dog is Dog {" in code
