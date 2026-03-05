import unittest
import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestMatchNarrowing(TranspilerTest):
    def test_union_type_narrowing_in_match(self):
        code = """
from typing import Union

class A:
    a: int = 1

class B:
    b: str = "b"

def test_match(x: Union[A, B]):
    match x:
        case A():
            return x.a
        case B():
            return x.b
"""
        type_inference = TypeInference()
        # Mocking what mypy would provide
        type_inference.type_map["x"] = "A | B"
        # Narrowed types for usages of x
        # return x.a is at line 13, x is at col 19
        type_inference.type_map["x@13:19"] = "A"
        # return x.b is at line 15, x is at col 19
        type_inference.type_map["x@15:19"] = "B"

        translator = VNodeVisitor(type_inference)
        tree = ast.parse(code)
        translator.visit(tree)
        v_code = translator.emitter.emit()

        # Check if casts are emitted
        assert "(x as A).a" in v_code
        assert "(x as B).b" in v_code

    def test_capture_pattern_narrowing(self):
        code = """
from typing import Union

class A:
    a: int = 1

def test_match(x: object):
    match x:
        case A() as a_val:
            return a_val.a
"""
        type_inference = TypeInference()
        type_inference.type_map["x"] = "Any"
        # MatchAs pattern for a_val is at line 9, col 13
        type_inference.type_map["a_val@9:13"] = "A"
        # Usage of a_val is at line 10, col 19
        type_inference.type_map["a_val@10:19"] = "A"

        translator = VNodeVisitor(type_inference)
        tree = ast.parse(code)
        translator.visit(tree)
        v_code = translator.emitter.emit()

        # The assignment should be narrowed
        assert "a_val := (_match_subject_any_1 as A)" in v_code
        # Usage should be casted (or if it's already A, maybe not needed, but NamesMixin will do it)
        assert "return (a_val as A).a" in v_code

    def test_nested_capture_narrowing(self):
        code = """
class Box:
    item: object

class Point:
    x: int
    y: int

def test_match(box: Box):
    match box.item:
        case Point(x=x_val) as p:
            return x_val + p.y
"""
        type_inference = TypeInference()
        type_inference.type_map["box"] = "Box"
        type_inference.type_map["Box.item"] = "Any"

        # Point(x=x_val) as p
        # x_val is at line 11, col 21
        # p is at line 11, col 30
        type_inference.type_map["x_val@11:21"] = "int"
        type_inference.type_map["p@11:30"] = "Point"

        # Usages
        type_inference.type_map["x_val@12:19"] = "int"
        type_inference.type_map["p@12:27"] = "Point"

        translator = VNodeVisitor(type_inference)
        tree = ast.parse(code)
        translator.visit(tree)
        v_code = translator.emitter.emit()

        assert "p := (_match_subject_any_1 as Point)" in v_code
        assert "x_val := ((_match_subject_any_1 as Point).x as Any)" in v_code
        assert "return x_val + (p as Point).y" in v_code

if __name__ == "__main__":
    unittest.main()
