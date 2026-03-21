import ast
import sys
import pytest
from py2v_transpiler.core.translator import VNodeVisitor

class MockTypeInference:
    def __init__(self):
        self.type_map = {}
        self.call_signatures = {}
    def resolve_type(self, node):
        return "void"

def transpile_code(code: str) -> str:
    tree = ast.parse(code)
    inference = MockTypeInference()
    visitor = VNodeVisitor(inference)
    visitor.visit(tree)
    return visitor.emitter.emit()

@pytest.mark.skipif(sys.version_info < (3, 12), reason="PEP 695 requires Python 3.12+")
def test_nested_function_generics():
    code = """
def outer[T](x: T):
    def inner[U](y: U) -> T:
        return x
    return inner
"""
    v_code = transpile_code(code)
    # T -> T, U -> U (assuming first available)
    assert "fn inner[T, U](y U) T {" in v_code
    assert "return x" in v_code
    assert "fn outer[T](x T) {" in v_code

@pytest.mark.skipif(sys.version_info < (3, 12), reason="PEP 695 requires Python 3.12+")
def test_nested_class_generics():
    code = """
class Outer[T]:
    class Inner[U]:
        val: T
        other: U
"""
    v_code = transpile_code(code)
    assert "struct OuterInner[T, U] {" in v_code
    assert "val T" in v_code
    assert "other U" in v_code
    assert "struct Outer[T] {" in v_code

@pytest.mark.skipif(sys.version_info < (3, 12), reason="PEP 695 requires Python 3.12+")
def test_mixed_nesting():
    code = """
class Outer[T]:
    def method[U](self, x: T, y: U):
        def inner[V](z: V) -> T:
            return x
        return inner
"""
    v_code = transpile_code(code)
    assert "fn inner[T, U, V](z V) T {" in v_code
    # V methods mangle names: Outer_method
    assert "fn (self Outer[T]) method[T, U](x T, y U) {" in v_code

@pytest.mark.skipif(sys.version_info < (3, 12), reason="PEP 695 requires Python 3.12+")
def test_generic_shadowing():
    code = """
def outer[T](x: T):
    def inner[T](y: T) -> T:
        return y
    return inner
"""
    v_code = transpile_code(code)
    # The inner T should map to a different V generic if it's already used
    # But wait, our _get_generic_map checks used_chars.
    # outer[T] -> T
    # inner[T] -> U (or something else because T is used)
    assert "fn inner[T, U](y U) U {" in v_code
    assert "fn outer[T](x T) {" in v_code

if __name__ == "__main__":
    if sys.version_info >= (3, 12):
        # Simple manual run
        print(transpile_code("def outer[T](x: T):\n    def inner[U](y: U) -> T:\n        return x"))
    else:
        print("Skipping manual run (Python < 3.12)")
