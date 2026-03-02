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
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_overload_add_operator():
    source = """
from typing import overload

class Vector:
    @overload
    def __add__(self, other: 'Vector') -> 'Vector':
        pass

    @overload
    def __add__(self, other: int) -> 'Vector':
        pass

    def __add__(self, other):
        return self
"""
    v_code = translate(source)
    print("------- V CODE -------")
    print(v_code)
    print("----------------------")
    # Both overloads should be emitted as overloaded operators?
    # V actually does NOT support multiple overloaded operators for the same type if LHS is same?
    # Wait, V operator overloading signature is:
    # fn (a T) + (b U) R
    # Can we have both `fn (a Vector) + (b Vector) Vector` and `fn (a Vector) + (b int) Vector`?
    # Yes! V supports overloading operators with different RHS types.

    assert "fn (self Vector) + (other Vector) Vector {" in v_code
    assert "fn (self Vector) + (other int) Vector {" in v_code
