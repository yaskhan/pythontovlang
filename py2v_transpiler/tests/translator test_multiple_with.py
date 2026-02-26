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
    return translator.visit_Module(tree)

def test_multiple_context_managers():
    source = """
with open("file1.txt") as f1, open("file2.txt") as f2:
    data = f1.read() + f2.read()
"""
    v_code = translate(source)
    assert "f1 :=" in v_code
    assert "f2 :=" in v_code
    assert "defer" in v_code

def test_three_context_managers():
    source = """
with open("a.txt") as a, open("b.txt") as b, open("c.txt") as c:
    pass
"""
    v_code = translate(source)
    assert "a :=" in v_code
    assert "b :=" in v_code
    assert "c :=" in v_code

def test_context_manager_no_var():
    source = """
with open("file.txt"):
    pass
"""
    v_code = translate(source)
    assert "os.open" in v_code or "defer" in v_code
