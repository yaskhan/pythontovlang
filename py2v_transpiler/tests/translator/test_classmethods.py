import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_classmethod_on_generic_class():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
from typing import Generic, TypeVar, Any

T = TypeVar('T')

class UserDict(Generic[T]):
    @classmethod
    def fromkeys(cls, iterable: Any, value: Any = None) -> 'UserDict[T]':
        \"\"\"Create new instance from iterable.\"\"\"
        return cls()
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Current issues expected:
    # 1. 'cls int' in signature
    # 2. wrong generic name in function decl if it was generic (fromkeys[T])
    # 3. wrong return type

    # Expected V Output (Ideal):
    # fn UserDict_fromkeys[T](iterable Any, value Any) UserDict[T] {
    #    // Create new instance from iterable.
    #    return UserDict[T]{}
    # }

    print(result)

    assert "fn UserDict_fromkeys[T](iterable Any, value Any) UserDict[T] {" in result
    assert "cls int" not in result
    assert "return UserDict[T]{}" in result

def test_overloaded_classmethod_on_generic_class():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
from typing import Generic, TypeVar, Any, Iterable, overload

T = TypeVar('T')

class UserDict(Generic[T]):
    @overload
    @classmethod
    def fromkeys(cls, iterable: Iterable[T]) -> 'UserDict[T]': ...

    @classmethod
    def fromkeys(cls, iterable: Any, value: Any = None) -> 'UserDict[T]':
        return cls()
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    print(result)

    # Check that cls is NOT in the overloaded variant signature
    # Signature of fromkeys_iterable_T should NOT have cls
    assert "fn UserDict_fromkeys_arr_generic[T](cls int" not in result
    assert "fn UserDict_fromkeys_arr_generic[T](" in result
    assert "UserDict[T]{}" in result # return UserDict[T]() -> return UserDict[T]{}
