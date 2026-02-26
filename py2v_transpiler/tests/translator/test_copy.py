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

def test_copy_copy():
    source = """
import copy
orig = [1, 2, 3]
copied = copy.copy(orig)
"""
    v_code = translate(source)
    # Check that copy.copy is mapped to py_copy
    assert "copied := py_copy(orig)" in v_code
    # Import copy in V? If mapped to py_copy, we don't need 'import copy' in V.
    # But mapper handles 'import copy' -> 'import arrays' maybe? Or just suppressed if helpers are used.
    # Check that 'import copy' is NOT present as raw 'import copy'
    assert "import copy" not in v_code
    # Check helpers are present (indirectly, if we implement them)
    # But here we just check mapping.

def test_copy_deepcopy():
    source = """
import copy
orig = {'a': 1}
deep_copied = copy.deepcopy(orig)
"""
    v_code = translate(source)
    assert "deep_copied := py_deepcopy(orig)" in v_code

def test_copy_on_primitive():
    source = """
import copy
x = 1
y = copy.copy(x)
"""
    v_code = translate(source)
    assert "y := py_copy(x)" in v_code
