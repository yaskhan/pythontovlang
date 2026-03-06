
import ast
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_transpile(code):
    tree = ast.parse(code)
    ti = TypeInference()
    ti.analyze(tree)
    visitor = VNodeVisitor(ti)
    # visitor.visit(tree) for Module returns the transpiled string
    output = visitor.visit(tree)
    print("--- Python Code ---")
    print(code)
    print("--- Transpiled V Code ---")
    print(output)

code = "[num for row in matrix for num in row if num % 2 == 0]"
test_transpile(code)
