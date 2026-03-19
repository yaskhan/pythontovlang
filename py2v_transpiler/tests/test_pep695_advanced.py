import unittest
import ast
import sys
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

def transpile_code(source_code: str) -> str:
    parser = PyASTParser()
    tree = parser.parse(source_code)
    analyzer = TypeInference()
    analyzer.analyze(tree)
    translator = VNodeVisitor(analyzer)
    return translator.visit_Module(tree)

@pytest.mark.skipif(sys.version_info < (3, 12), reason="PEP 695 requires Python 3.12+")
class TestPEP695Advanced(unittest.TestCase):
    def test_paramspec_generic_function(self):
        code = """
def call_func[**P, R](func: Callable[P, R]) -> R:
    return func()
"""
        v_code = transpile_code(code)
        # PEP 695 generics are mapped to single characters like T, R, P, etc.
        self.assertIn("fn call_func[", v_code)
        self.assertIn("func fn ()", v_code)

    def test_typevartuple_generic_class(self):
        code = """
class MyContainer[*Ts](Generic[*Ts]):
    pass
"""
        v_code = transpile_code(code)
        self.assertIn("struct MyContainer[", v_code)

    def test_typevartuple_unpacking(self):
        code = """
def process_tuple[*Ts](args: tuple[*Ts]) -> int:
    return len(args)
"""
        v_code = transpile_code(code)
        self.assertIn("fn process_tuple[", v_code)
        # tuple[*Ts] -> tuple[T] (Generic name mapped to T, single starred elt maps to tuple[T])
        self.assertIn("args TupleStruct_T", v_code)

    def test_callable_with_unpacking(self):
        code = """
def higher_order[*Ts, R](func: Callable[[int, *Ts], R]) -> R:
    pass
"""
        v_code = transpile_code(code)
        # Callable[[int, *Ts], R] -> fn (int, T) R (where Ts maps to T)
        self.assertIn("func fn (int, ", v_code)

if __name__ == "__main__":
    unittest.main()
