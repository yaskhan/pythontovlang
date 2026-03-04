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
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code + "\n" + helpers

def test_typing_import():
    source = """
from typing import List, Dict, Optional
x: List[int] = []
"""
    v_code = translate(source)
    # typing import is suppressed
    assert "import typing" not in v_code
    # Annotation is not emitted in assignment (x := []), but x is used.
    # We check that it doesn't crash and emits valid code.
    assert "x := []int{}" in v_code or "x := []" in v_code # Depending on list literal mapping

def test_type_alias_list():
    source = """
from typing import List
MyList = List[int]
"""
    v_code = translate(source)
    # Should emit type alias
    assert "type MyList = []int" in v_code

def test_type_alias_dict():
    source = """
from typing import Dict
MyDict = Dict[str, int]
"""
    v_code = translate(source)
    assert "type MyDict = map[string]int" in v_code

def test_type_alias_optional():
    source = """
from typing import Optional
MaybeInt = Optional[int]
"""
    v_code = translate(source)
    assert "type MaybeInt = ?int" in v_code

def test_type_alias_union():
    source = """
from typing import Union
IntOrStr = Union[int, str]
"""
    v_code = translate(source)
    # V union types are not fully supported via type alias syntax always (sum types usually require struct wrapper or interface)
    # But map_python_type_to_v returns "int | string".
    # V syntax `type MySum = int | string` is valid for sum types.
    assert "type IntOrStr = int | string" in v_code

def test_variable_assignment_list_literal():
    # Regression check: ensure normal variable assignment is not treated as type alias
    source = """
MyVar = [1, 2]
"""
    v_code = translate(source)
    assert "my_var := [1, 2]" in v_code
    assert "type MyVar" not in v_code
