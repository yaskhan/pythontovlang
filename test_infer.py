import ast
from py2v_transpiler.core.analyzer import TypeInference

code = """
def process(data: dict) -> None:
    data['key'] = 'value'

def wrapper(d: dict) -> None:
    process(d)
"""
tree = ast.parse(code)
from py2v_transpiler.core.analyzer import FunctionMutabilityScanner
mut_scanner = FunctionMutabilityScanner()
func_param_mutability = mut_scanner.analyze(tree)
print("func_param_mutability:", func_param_mutability)

ti = TypeInference()
ti.analyze(tree)
print("ti.mutability_map:", ti.mutability_map)
