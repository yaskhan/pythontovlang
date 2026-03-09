import unittest
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
class TestPEP695(unittest.TestCase):
    def test_generic_function(self):
        code = "def func[T](x: T) -> T: return x"
        v_code = transpile_code(code)
        self.assertIn("fn func[T](x T) T {", v_code)

    def test_generic_class(self):
        code = """
class Box[T]:
    value: T
"""
        v_code = transpile_code(code)
        self.assertIn("struct Box[T] {", v_code)
        self.assertIn("    value T", v_code)

    def test_generic_type_alias(self):
        code = "type Alias[T] = list[T]"
        v_code = transpile_code(code)
        self.assertIn("type Alias[T] = []T", v_code)

    def test_paramspec_args_kwargs(self):
        code = """
def wrapper[**P](*args: P.args, **kwargs: P.kwargs) -> None:
    pass
"""
        v_code = transpile_code(code)
        self.assertIn("fn wrapper[P](args ...P, kwargs map[string]Any) {", v_code)

    def test_typevartuple_starred(self):
        code = """
def head[*Ts](first: int, *rest: *Ts) -> int:
    return first
"""
        v_code = transpile_code(code)
        self.assertIn("fn head[T](first int, rest ...T) int {", v_code)

if __name__ == "__main__":
    unittest.main()
