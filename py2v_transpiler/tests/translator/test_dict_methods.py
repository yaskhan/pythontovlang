import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def translate_full(source: str):
    parser = PyASTParser()
    tree = parser.parse(source)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    v_code = translator.visit_Module(tree)
    helpers = translator.emitter.emit_helpers()
    return v_code, helpers

def test_dict_update():
    source = """
d1 = {"a": 1}
d2 = {"b": 2}
d1.update(d2)
d1.update(c=3)
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_update(mut d1, d2)" in v_code
    assert "py_dict_update(mut d1, {'c': 3})" in v_code
    assert "fn py_dict_update" in helpers

def test_dict_setdefault():
    source = """
d = {"a": 1}
val = d.setdefault("b", 2)
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_setdefault(mut d, 'b', 2)" in v_code
    assert "fn py_dict_setdefault" in helpers

def test_dict_pop():
    source = """
d = {"a": 1}
val = d.pop("a")
val2 = d.pop("b", 0)
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_pop(mut d, 'a', none)" in v_code
    assert "py_dict_pop(mut d, 'b', 0)" in v_code
    assert "fn py_dict_pop" in helpers

def test_dict_fromkeys():
    source = """
keys = ["a", "b"]
d = dict.fromkeys(keys, 0)
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_fromkeys<map[string]Any>(keys, 0)" in v_code
    assert "fn py_dict_fromkeys" in helpers

def test_dict_constructor_pairs():
    source = """
d = dict([("a", 1), ("b", 2)])
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_from_pairs<map[string]Any>([['a', 1], ['b', 2]])" in v_code
    assert "fn py_dict_from_pairs" in helpers

def test_dict_kwargs():
    source = "d = dict(a=1, b=2)"
    v_code, _ = translate_full(source)
    assert "d := {'a': 1, 'b': 2}" in v_code

def test_dict_mix_pos_kwargs():
    source = """
other = {"a": 1}
d = dict(other, b=2)
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_update(mut map[string]Any(other).clone(), {'b': 2})" in v_code
    assert "fn py_dict_update" in helpers

def test_dict_fromkeys_custom_default():
    source = """
keys = ["a", "b"]
d = dict.fromkeys(keys, [])
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_fromkeys<map[string]Any>(keys, []Any{})" in v_code
    assert "fn py_dict_fromkeys" in helpers

def test_dict_pop_no_default():
    source = """
d = {"a": 1}
d.pop("a")
"""
    v_code, _ = translate_full(source)
    assert "py_dict_pop(mut d, 'a', none)" in v_code

def test_dict_any_type():
    source = """
def foo(d: Any):
    d.pop("key")
    d.update({"x": 1})
"""
    v_code, helpers = translate_full(source)
    assert "py_dict_pop(mut d, 'key', none)" in v_code
    assert "py_dict_update(mut d, {'x': 1})" in v_code
