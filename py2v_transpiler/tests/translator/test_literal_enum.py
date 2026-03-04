import unittest
from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestLiteralEnum(TranspilerTest):
    def test_literal_string_alias(self):
        code = """
        from typing import Literal
        Mode = Literal['read', 'write', 'append']
        """
        # We map to base type for compatibility while tracking allowed values
        expected = """
        type Mode = string
        """
        self.assert_transpilation(code, expected)

    def test_literal_int_alias(self):
        code = """
        from typing import Literal
        Status = Literal[1, 2, 3]
        """
        expected = """
        type Status = int
        """
        self.assert_transpilation(code, expected)

    def test_literal_annotation_check(self):
        code = """
        from typing import Literal
        def foo():
            x: Literal['a', 'b'] = 'a'
            y: Literal['a', 'b'] = 'c'
        """
        # We expect y assignment to emit a compile error in V
        expected = """
        fn foo() {
            x := 'a'
            $compile_error('Invalid literal value \\"c\\" for Literal[\\'a\\', \\'b\\']')
            y := 'c'
        }
        """
        # The exact format might vary depending on implementation
        self.assert_transpilation(code, expected)

    def test_named_literal_annotation_check(self):
        code = """
        from typing import Literal
        Mode = Literal['r', 'w']
        def foo():
            m: Mode = 'a'
        """
        expected = """
        fn foo() {
            $compile_error('Invalid literal value \\"a\\" for Mode')
            m := 'a'
        }
        """
        self.assert_transpilation(code, expected)

if __name__ == '__main__':
    unittest.main()
