import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_property_setter_return_type():
    source = """
class Temperature:
    def __init__(self, celsius: float):
        self._celsius = celsius

    @property
    def celsius(self) -> float:
        return self._celsius

    @celsius.setter
    def celsius(self, value: float):
        if value < -273.15:
            raise ValueError("Below absolute zero")
        self._celsius = value
"""
    tree = ast.parse(source)
    inference = TypeInference()
    inference.analyze(tree)

    visitor = VNodeVisitor(inference)
    code = visitor.visit(tree)

    # The issue is that the setter currently returns f64 (or float equivalent)
    # It should be void.

    # Expected V signature for setter:
    # fn (mut self Temperature) set_celsius(value f64) {

    assert "fn (mut self Temperature) set_celsius(value f64) {" in code
    assert "fn (mut self Temperature) set_celsius(value f64) f64 {" not in code

if __name__ == "__main__":
    test_property_setter_return_type()
