import ast
from py2v_transpiler.tests.translator.test_typed_dict import _TestTranslator

def test_pep705_readonly_struct_generation():
    code = """
from typing import TypedDict, ReadOnly

class MyDict(TypedDict):
    a: int
    b: ReadOnly[str]
    c: float
"""
    tree = ast.parse(code)
    translator = _TestTranslator()
    translator.visit(tree)

    structs = translator.emitter.structs
    struct_code = next(s for s in structs if "struct MyDict" in s)

    print("STRUCT_CODE:")
    print(struct_code)

    # Check for access modifiers. Currently they might be missing.
    # We want something like:
    # pub mut:
    #     a int
    # pub:
    #     b string
    # pub mut:
    #     c f64

    # Since we want to implement this, we expect these to eventually be there.
    # For now, let's see what's actually there.
    assert "a int" in struct_code
    assert "b string" in struct_code
    assert "c f64" in struct_code

def test_pep705_readonly_attribute_assignment_error():
    code = """
from typing import TypedDict, ReadOnly

class MyDict(TypedDict):
    a: int
    b: ReadOnly[str]

d: MyDict = {"a": 1, "b": "hello"}
d.b = "world"
"""
    tree = ast.parse(code)
    translator = _TestTranslator()
    # Simulate mypy inferring type
    translator.type_inference.type_map["d"] = "MyDict"
    translator.visit(tree)

    v_code = "\n".join(translator.output)
    print("V_CODE:")
    print(v_code)

    # This should trigger a compile error
    assert "$compile_error('Cannot assign to ReadOnly TypedDict field \\'b\\'')" in v_code

def test_pep705_readonly_subscript_assignment_error():
    code = """
from typing import TypedDict, ReadOnly

class MyDict(TypedDict):
    a: int
    b: ReadOnly[str]

d: MyDict = {"a": 1, "b": "hello"}
d["b"] = "world"
"""
    tree = ast.parse(code)
    translator = _TestTranslator()
    # Simulate mypy inferring type
    translator.type_inference.type_map["d"] = "MyDict"
    translator.visit(tree)

    v_code = "\n".join(translator.output)
    print("V_CODE:")
    print(v_code)

    # This should trigger a compile error
    assert "$compile_error('Cannot assign to ReadOnly TypedDict field \\'b\\'')" in v_code

def test_pep705_typing_readonly_detection():
    code = """
import typing

class MyDict(typing.TypedDict):
    a: typing.ReadOnly[int]
"""
    tree = ast.parse(code)
    translator = _TestTranslator()
    translator.visit(tree)

    # Check if 'a' was correctly identified as ReadOnly
    assert "MyDict" in translator.readonly_fields
    assert "a" in translator.readonly_fields["MyDict"]

if __name__ == "__main__":
    # For manual debugging
    test_pep705_readonly_struct_generation()
    test_pep705_readonly_attribute_assignment_error()
    test_pep705_typing_readonly_detection()
