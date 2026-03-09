from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def test_pre_allocated_capacity_ann_assign():
    code = """
def test():
    arr: list[int] = [1, 2, 3]
    arr.append(4)
"""
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree) # Use analyze instead of visit to run mutability scanner
    translator = VNodeVisitor(analyzer)
    out = translator.visit_Module(tree)

    assert "mut arr := [1, 2, 3]" in out


def test_pre_allocated_capacity_assign_inferred():
    code = """
def test():
    arr = [1, 2, 3]
    arr.append(4)
"""
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.analyze(tree)

    # Simulate mypy providing the exact type for 'arr'
    analyzer.type_map["arr"] = "[]int"

    translator = VNodeVisitor(analyzer)
    out = translator.visit_Module(tree)

    assert "mut arr := []int{cap: 3}" in out
    assert "arr << 1" in out
    assert "arr << 2" in out
    assert "arr << 3" in out

def test_no_pre_allocation_for_dynamic_lists():
    code = """
def test():
    arr: list[int] = [*other, 3]
"""
    parser = PyASTParser()
    tree = parser.parse(code)
    analyzer = TypeInference()
    analyzer.visit(tree)
    translator = VNodeVisitor(analyzer)
    out = translator.visit_Module(tree)

    # Due to *other, it cannot be safely pre-allocated
    assert "{cap: " not in out
    assert "arr := py_list_concat" in out
