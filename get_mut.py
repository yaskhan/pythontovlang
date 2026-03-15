import ast
from py2v_transpiler.core.analyzer import TypeInference

with open("py2v_transpiler/tests/input/transpile/test_none_type.py") as f:
    code = f.read()

tree = ast.parse(code)
ti = TypeInference()
ti.visit(tree)
print("x:", ti.mutability_map.get("x"))
print("get_value.x:", ti.mutability_map.get("get_value.x"))
