import ast
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile(source_code: str) -> str:
    tree = ast.parse(source_code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

def test_type_alias_infer_single_type():
    python_code = """
class Constraint:
    pass

OrderedCollection = list

def foo():
    a = OrderedCollection()
    a.append(Constraint())
    return a
"""
    v_code = transpile(python_code)
    assert "type OrderedCollection = []Constraint" in v_code

def test_type_alias_infer_multiple_types():
    python_code = """
class Constraint:
    pass

class Variable:
    pass

OrderedCollection = list

def foo():
    a = OrderedCollection()
    a.append(Constraint())
    return a

def bar():
    b = OrderedCollection()
    b.append(Variable())
    return b
"""
    v_code = transpile(python_code)
    assert "type OrderedCollection = []Any" in v_code

def test_type_alias_infer_no_append():
    python_code = """
OrderedCollection = list

def foo():
    a = OrderedCollection()
    return a
"""
    v_code = transpile(python_code)
    assert "type OrderedCollection = []Any" in v_code
