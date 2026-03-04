from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_translator_elif():
    parser = PyASTParser()
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    code = """
number = 15
if number > 10:
    print("A")
elif number > 5:
    print("B")
elif number > 2:
    print("C")
else:
    print("D")
"""
    tree = parser.parse(code)
    analyzer.analyze(tree)
    result = translator.visit_Module(tree)

    print(result)

    # Current output would have nested else { if ... }
    # We want to check if it contains "else if"
    assert "else if number > 5 {" in result
    assert "else if number > 2 {" in result
    assert "else {" in result

if __name__ == "__main__":
    test_translator_elif()
