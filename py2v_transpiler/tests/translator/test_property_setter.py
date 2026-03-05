import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_property_setter():
    source = """
class Person:
    _name: str = "Unknown"

    def __init__(self):
        self._name = "Unknown"

    @property
    def name(self) -> str:
        return self._name

    @name.setter
    def name(self, value: str):
        self._name = value
"""
    expected_fragments = [
        "fn (self Person) name() string {",
        "return self.py_name",
        "}",
        "fn (self Person) set_name(value string) {",
            "self.py_name = value"
    ]

    visitor = VNodeVisitor(TypeInference())
    tree = ast.parse(source)
    code = visitor.visit(tree)

    print(code)

    for fragment in expected_fragments:
        assert fragment in code, f"Expected '{fragment}' in generated code"
