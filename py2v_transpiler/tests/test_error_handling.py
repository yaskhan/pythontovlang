import unittest
import ast
from py2v_transpiler.main import Transpiler
from py2v_transpiler.config import TranspilerConfig
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor

class TestErrorRecoveryAndMapping(unittest.TestCase):
    def test_source_mapping_comments(self):
        source = "def foo():\n    pass\n\nclass Bar:\n    x: int = 1"
        config = TranspilerConfig(source_mapping=True, mypy_enabled=False)

        parser = PyASTParser()
        tree = parser.parse(source)
        analyzer = TypeInference()
        analyzer.analyze(tree)
        translator = VNodeVisitor(analyzer, config=config)
        translator.current_file_name = "test.py"
        v_code = translator.visit_Module(tree)

        self.assertIn("// @line: test.py:1:0", v_code)
        self.assertIn("// @line: test.py:4:0", v_code)

    def test_syntax_error_reporting(self):
        source = "if True\n    pass" # Missing colon
        parser = PyASTParser()
        with self.assertRaises(SyntaxError) as cm:
            parser.parse(source)
        self.assertIn("(at 1:", str(cm.exception))

    def test_transpilation_error_recovery(self):
        # We need a node that causes an exception during translation
        # Let's mock a visitor that fails on a specific node
        source = "x = 1\nunknown_node_trigger()\ny = 2"

        class FailingTranslator(VNodeVisitor):
            def visit_Call(self, node):
                if isinstance(node.func, ast.Name) and node.func.id == "unknown_node_trigger":
                    raise ValueError("Triggered failure")
                return super().visit_Call(node)

        parser = PyASTParser()
        tree = parser.parse(source)
        analyzer = TypeInference()
        analyzer.analyze(tree)

        config = TranspilerConfig(mypy_enabled=False)
        translator = FailingTranslator(analyzer, config=config)
        translator.current_file_name = "test_fail.py"

        v_code = translator.visit_Module(tree)

        # Check if it recovered and processed y = 2
        self.assertIn("x := 1", v_code)
        self.assertIn("y := 2", v_code)
        self.assertIn("/* Error transpiling node at test_fail.py:2:0: Triggered failure */", v_code)
        self.assertTrue(any("Triggered failure" in w for w in translator.warnings))

if __name__ == "__main__":
    unittest.main()
