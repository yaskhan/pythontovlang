import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    analyzer.visit(tree) # Run type inference first
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

def test_add_operator():
    source = """
class Vector:
    def __add__(self, other: 'Vector') -> 'Vector':
        return Vector(self.x + other.x, self.y + other.y)
"""
    v_code = translate(source)
    # Check for V operator overloading syntax: fn (self Vector) + (other Vector) Vector
    assert "fn (self Vector) + (other Vector) Vector {" in v_code

def test_sub_operator():
    source = """
class Point:
    def __sub__(self, other: 'Point') -> 'Point':
        return Point(self.x - other.x, self.y - other.y)
"""
    v_code = translate(source)
    assert "fn (self Point) - (other Point) Point {" in v_code

def test_mul_operator_scalar():
    source = """
class Vector:
    def __mul__(self, scalar: int) -> 'Vector':
        return Vector(self.x * scalar, self.y * scalar)
"""
    v_code = translate(source)
    # Argument name is scalar, type is int
    assert "fn (self Vector) * (scalar int) Vector {" in v_code

def test_eq_operator():
    source = """
class Box:
    def __eq__(self, other: 'Box') -> bool:
        return self.val == other.val
"""
    v_code = translate(source)
    assert "fn (self Box) == (other Box) bool {" in v_code

def test_str_method():
    source = """
class Foo:
    def __str__(self) -> str:
        return "Foo"
"""
    v_code = translate(source)
    assert "fn (self Foo) str() string {" in v_code
