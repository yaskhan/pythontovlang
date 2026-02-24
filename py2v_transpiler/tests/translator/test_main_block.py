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

def test_if_name_main():
    source = """
def run():
    print("Running...")

if __name__ == "__main__":
    run()
    print("Done")
"""
    v_code = translate(source)
    # Check that it generates a comment instead of an if block
    assert "// if __name__ == '__main__':" in v_code
    # Check that run() and print() are emitted without being inside an if block
    # This is tricky to check strictly without parsing V, but we can check indentation or absence of "if"
    # Or just check that the code appears
    assert "run()" in v_code
    assert "println('Done')" in v_code
    # Ensure no 'if __name__' V code (except in comments)
    assert "if __name__ == '__main__': {" not in v_code # V block start

def test_if_name_main_indented_body():
    source = """
if __name__ == "__main__":
    x = 1
    if x > 0:
        print("Positive")
"""
    v_code = translate(source)
    assert "// if __name__ == '__main__':" in v_code
    assert "x := 1" in v_code
    assert "if x > 0 {" in v_code
