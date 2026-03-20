import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_inheritance():
    source = """
class A:
    pass

class B(A):
    pass

class C(A, B): # Multiple inheritance (embedding)
    pass
"""
    # Note: V supports embedding structs.
    # Python MRO is complex, but for basic translation, embedding the bases as fields is the V way.
    # V does not support multiple inheritance in the same way, but multiple embedding is allowed (composition).

    expected_fragments = [
        "interface A {",
        "struct A_Impl {",
        "interface B {",
        "struct B_Impl {",
        "    A_Impl",
        "}",
        "struct C {",
        "    A_Impl",
        "    B_Impl",
        "}"
    ]

    analyzer = TypeInference()
    visitor = VNodeVisitor(analyzer)
    tree = ast.parse(source)
    analyzer.analyze(tree)
    code = visitor.visit(tree)

    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"
