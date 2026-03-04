
import ast
import pytest
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def transpile(code, base_types=None):
    tree = ast.parse(code)
    type_inference = TypeInference()
    if base_types:
        type_inference.type_map.update(base_types)
    type_inference.analyze(tree)
    translator = VNodeVisitor(type_inference)
    translator.visit(tree)
    return translator.emitter.emit()

def test_isinstance_narrowing():
    code = """
class Base: pass
class Derived(Base):
    def foo(self): pass

def test(obj: Base):
    if isinstance(obj, Derived):
        obj.foo()
"""
    v_code = transpile(code, {"obj": "Base"})
    assert "(obj as Derived).foo()" in v_code

def test_none_narrowing():
    code = """
def test(obj: int | None):
    if obj is not None:
        return obj + 1
    return 0
"""
    # Note: map_python_type_to_v maps int | None to ?int
    v_code = transpile(code, {"obj": "?int"})
    # In V, for primitive types we use functional cast for unwrapping: int(obj)
    assert "int(obj) + 1" in v_code

def test_assert_narrowing():
    code = """
class Base: pass
class Derived(Base):
    def foo(self): pass

def test(obj: Base):
    assert isinstance(obj, Derived)
    obj.foo()
"""
    v_code = transpile(code, {"obj": "Base"})
    assert "(obj as Derived).foo()" in v_code

def test_while_narrowing():
    code = """
class Base: pass
class Derived(Base):
    def foo(self): pass

def test(obj: Base):
    while isinstance(obj, Derived):
        obj.foo()
"""
    v_code = transpile(code, {"obj": "Base"})
    assert "(obj as Derived).foo()" in v_code

def test_nested_narrowing():
    code = """
class A: pass
class B(A): pass
class C(B):
    def foo(self): pass

def test(obj: A):
    if isinstance(obj, B):
        if isinstance(obj, C):
            obj.foo()
"""
    v_code = transpile(code, {"obj": "A"})
    assert "(obj as C).foo()" in v_code

def test_and_narrowing():
    code = """
class Base: pass
class Derived(Base):
    def foo(self): pass

def test(obj: Base):
    if isinstance(obj, Derived) and True:
        obj.foo()
"""
    v_code = transpile(code, {"obj": "Base"})
    assert "(obj as Derived).foo()" in v_code
