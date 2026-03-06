import unittest
from py2v_transpiler.main import Transpiler
from py2v_transpiler.config import TranspilerConfig
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
import ast

class TestPEP747(unittest.TestCase):
    def test_typeform_experimental_warning(self):
        code = """
from typing_extensions import TypeForm
def foo(tf: TypeForm[int]): pass
"""
        analyzer = TypeInference()
        tree = ast.parse(code)
        analyzer.analyze(tree)

        # Test WITHOUT experimental flag
        config_no_exp = TranspilerConfig(experimental=False)
        translator = VNodeVisitor(analyzer, config=config_no_exp)
        translator.visit_Module(tree)
        self.assertTrue(any("Experimental feature 'TypeForm'" in w for w in translator.warnings))

        # Test WITH experimental flag
        config_exp = TranspilerConfig(experimental=True)
        translator = VNodeVisitor(analyzer, config=config_exp)
        translator.visit_Module(tree)
        self.assertFalse(any("Experimental feature 'TypeForm'" in w for w in translator.warnings))

    def test_typeform_mapping(self):
        code = """
from typing_extensions import TypeForm
def foo(tf: TypeForm[int]) -> TypeForm[str]:
    return str
"""
        transpiler = Transpiler()
        result = transpiler.transpile(code)
        self.assertIn("tf Any", result)
        self.assertIn("fn foo(tf Any) Any", result)

if __name__ == "__main__":
    unittest.main()
