import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_hasattr():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    # By default, obj is guessed as 'int' if unknown?
    # Actually _guess_type returns 'int' as fallback.
    # So obj_type is 'int', hasattr should return "false".
    code = "x = hasattr(obj, 'attr')"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := false" in result

def test_hasattr_any():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    # Set type to Any
    analyzer.type_map = {"obj": "Any"}
    code = "x = hasattr(obj, 'attr')"
    tree = parser.parse(code)
    result = translator.visit_Module(tree)

    assert "x := //##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n$if obj.has_field('attr') { true } $else { false }" in result

def test_hasattr_struct():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    analyzer.type_map = {"obj": "MyStruct"}
    code = "x = hasattr(obj, 'attr')"
    tree = parser.parse(code)
    result = translator.visit_Module(tree)

    assert "x := //##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n$if obj.has_field('attr') { true } $else { false }" in result

def test_hasattr_known_dataclass():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    # We fake that we visited a dataclass earlier
    translator.dataclasses = {"MyStruct": ["x", "attr"]}

    analyzer.type_map = {"obj": "MyStruct"}
    code = "b = hasattr(obj, 'attr')"
    tree = parser.parse(code)
    result = translator.visit_Module(tree)

    assert "b := true" in result

def test_getattr_literal():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = getattr(obj, 'attr')"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := //##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\nobj.attr" in result

def test_getattr_dynamic():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = getattr(obj, var)"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "x := //##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* getattr(obj, var) - dynamic access not supported */" in result

def test_setattr_literal():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "setattr(obj, 'attr', 1)"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "obj.attr = 1" in result

def test_setattr_dynamic():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "setattr(obj, var, 1)"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.\n/* setattr(obj, var, 1) - dynamic setting not supported */" in result
