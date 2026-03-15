import ast
from py2v_transpiler.core.analyzer import TypeInference

code = """
class Data:
    def __init__(self):
        self.val = 0

def modify(obj: Data) -> None:
    obj.val = 1

def wrapper(obj: Data) -> None:
    modify(obj)
"""
tree = ast.parse(code)
from py2v_transpiler.core.analyzer import FunctionMutabilityScanner
mut_scanner = FunctionMutabilityScanner()
func_param_mutability = mut_scanner.analyze(tree)
print("func_param_mutability:", func_param_mutability)

ti = TypeInference()
ti.analyze(tree)
print("ti.mutability_map:", ti.mutability_map)
