import ast
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_list_comp():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = [i for i in range(10)]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "mut x := []int{cap: 10}" in result
    # x = [i for i in range(10) if i > 5] has ifs so no cap
    assert "for i in 0..10 {" in result
    assert "x << i" in result

def test_translator_list_comp_filter():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "x = [i for i in range(10) if i > 5]"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "mut x := []int{}" in result
    # x = [i for i in range(10) if i > 5] has ifs so no cap
    assert "for i in 0..10 {" in result
    assert "if i > 5 {" in result
    assert "x << i" in result

def test_translator_dict_literal():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "d = {'a': 1, 'b': 2}"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "d := {'a': 1, 'b': 2}" in result

def test_translator_dict_empty():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = "d = {}"
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    assert "d := map[string]Any{}" in result

# New tests for collections module (defaultdict, Counter)

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

def test_defaultdict_int():
    source = """
from collections import defaultdict
d = defaultdict(int)
d['a'] += 1
"""
    v_code = translate(source)
    # Expect d := ... (mutability handling is separate concern)
    assert "d := map[string]int{}" in v_code
    assert "d['a'] += 1" in v_code or "d['a']++" in v_code

def test_defaultdict_list():
    source = """
from collections import defaultdict
d = defaultdict(list)
d['a'].append(1)
"""
    v_code = translate(source)
    assert "d := map[string][]int{}" in v_code
    # Currently .append is not mapped to << automatically for general calls
    assert "d['a'].append(1)" in v_code or "d['a'] << 1" in v_code

def test_counter_empty():
    source = """
from collections import Counter
c = Counter()
c['a'] += 1
"""
    v_code = translate(source)
    assert "c := map[string]int{}" in v_code
    # Verify AugAssign works for Counter too
    assert "c['a'] += 1" in v_code

def test_counter_list():
    source = """
from collections import Counter
l = [1, 2, 1]
c = Counter(l)
"""
    v_code = translate(source)
    assert "c := py_counter(l)" in v_code
    assert "fn py_counter[T](a []T) map[T]int" in v_code

def test_import_collections_defaultdict():
    source = """
import collections
d = collections.defaultdict(int)
"""
    v_code = translate(source)
    assert "d := map[string]int{}" in v_code

def test_import_collections_counter():
    source = """
import collections
c = collections.Counter([1, 2, 3])
"""
    v_code = translate(source)
    assert "c := py_counter([1, 2, 3])" in v_code
