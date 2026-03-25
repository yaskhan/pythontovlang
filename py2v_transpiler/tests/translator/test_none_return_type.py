import ast
import sys
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate(source: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source)
    if not isinstance(tree, ast.Module):
        raise ValueError("Parsed AST is not a Module")
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    return v_code

def test_simple_function_none_return():
    source = """
def foo(x: int) -> None:
    print(x)
"""
    v_code = translate(source)
    assert "fn foo(x int) {" in v_code
    assert "none" not in v_code
    assert "void" not in v_code

def test_function_explicit_return_none():
    source = """
def foo(x: int) -> None:
    if x > 0:
        return
    print(x)
"""
    v_code = translate(source)
    assert "fn foo(x int) {" in v_code
    assert "return" in v_code
    assert "return none" not in v_code

def test_function_return_none_value():
    source = """
def foo(x: int) -> None:
    return None
"""
    v_code = translate(source)
    assert "fn foo(x int) {" in v_code
    assert "return" in v_code
    assert "return none" not in v_code

def test_overloaded_none_return():
    source = """
from typing import overload

@overload
def foo(x: int) -> None: ...
@overload
def foo(x: str) -> None: ...

def foo(x):
    pass
"""
    v_code = translate(source)
    assert "fn foo_int(x int) {" in v_code
    assert "fn foo_string(x string) {" in v_code
    assert "none {" not in v_code
    assert "void {" not in v_code

def test_operator_overload_none_return():
    source = """
class A:
    def __add__(self, other: "A") -> None:
        pass
"""
    v_code = translate(source)
    assert "fn (self A) + (other &A) {" in v_code
    assert "void" not in v_code

def test_lambda_implicit_none():
    source = "f = lambda x: print(x)"
    v_code = translate(source)
    # V anonymous functions with no return value
    assert "f := fn (x int) { println('${x}') }" in v_code

def test_lambda_explicit_none():
    source = "f = lambda x: None"
    v_code = translate(source)
    # If lambda returns None, it should ideally be void, but if it is assigned,
    # it might need to return Any depending on how it's used.
    # Currently my fix makes it return Any because _guess_type(None) is Any.
    # Wait, I changed it to return 'none' in _guess_type in my previous turn,
    # but then reverted it to 'Any' because it broke a test.
    # Then I added special handling in visit_Lambda.
    assert "f := fn (x int) {}" in v_code

def test_method_none_return():
    source = """
class A:
    def foo(self) -> None:
        pass
"""
    v_code = translate(source)
    assert "fn (self A) foo() {" in v_code

def test_iter_method_none_return():
    source = """
class A:
    def __iter__(self) -> None:
        pass
"""
    v_code = translate(source)
    assert "fn (self A) iter() A {" in v_code
    assert "void" not in v_code
