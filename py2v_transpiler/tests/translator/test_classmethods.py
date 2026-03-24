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

    print(result)

    assert "fn UserDict_fromkeys[T](iterable Any, value Any) &UserDict[T] {" in result
    assert "cls int" not in result
    assert "return &UserDict[T]{}" in result

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
    assert "fn UserDict_fromkeys_arr_generic[T](cls int" not in result
    assert "fn UserDict_fromkeys_arr_generic[T](" in result
    assert "UserDict[T]{}" in result

def test_abstract_classmethod_on_generic_class():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
from typing import Generic, TypeVar, Any
from abc import ABC, abstractclassmethod

T = TypeVar('T')

class UserDict(Generic[T], ABC):
    @abstractclassmethod
    def fromkeys(cls, iterable: T, value: Any = None) -> 'UserDict[T]': ...
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    print(result)

    # Interface should not have cls in its methods
    assert "fromkeys(iterable T, value Any) &UserDict[T]" in result
    assert "cls int" not in result

def test_classmethod_name_mangling_generic_mismatch():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
from typing import Generic, TypeVar, Any, overload

T = TypeVar('T')

class UserDict(Generic[T]):
    @overload
    @classmethod
    def fromkeys(cls, iterable: T, value: Any = None) -> 'UserDict[T]': ...

    @classmethod
    def fromkeys(cls, iterable: T, value: Any = None) -> 'UserDict[T]':
        return cls()
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)

    # Force generic T to be recognized in type_map
    analyzer.type_map['T'] = 'T'

    result = translator.visit_Module(tree)
    print(result)

    # Generated name should use 'generic' instead of 'T' to be valid V
    assert "fn UserDict_fromkeys_generic_Any[T](" in result
    assert "cls int" not in result
