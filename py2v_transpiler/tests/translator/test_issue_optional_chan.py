import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_generator_optional_chan_issue():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
def my_counter(n: int):
    for i in range(n):
        yield i

def test():
    for num in my_counter(3):
        print(num)
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    # Check for the valid syntax (no optional ?)
    assert "ch_out chan int" in result
    assert "chan int{cap: 0}" in result
