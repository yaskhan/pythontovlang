
import ast
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.config import TranspilerConfig

def transpile(code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(code)

    analyzer = TypeInference()
    analyzer.analyze(tree)

    config = TranspilerConfig()
    visitor = VNodeVisitor(analyzer, config)
    return visitor.visit_Module(tree)

def test_repro():
    code = """
def list_operations(arr: list[int]) -> None:
    # 1. Negative indexing
    print("Last element:", arr[-1])
    print("Second to last:", arr[-2])
"""
    v_code = transpile(code)
    print(v_code)

if __name__ == "__main__":
    test_repro()
