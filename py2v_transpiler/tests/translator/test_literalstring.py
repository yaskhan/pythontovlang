import unittest
import ast
from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestLiteralString(TranspilerTest):
    def test_literalstring_constant(self):
        code = """
        from typing import LiteralString
        def foo():
            a: LiteralString = 'test'
        """
        expected = """
        fn foo() {
            a := 'test'
        }
        """
        self.assert_transpilation(code, expected)

    def test_literalstring_input_warning(self):
        code = """
        from typing import LiteralString
        def foo():
            a: LiteralString = input()
        """
        expected = """
        fn foo() {
            // WARNING: LiteralString variable 'a' receives value from input() (loss of guarantee)
            a := os.input('')
        }
        """
        self.assert_transpilation(code, expected)

    def test_literalstring_implicit(self):
        code = """
        a = 'test'
        b = 'a' + 'b'
        c = f"{a}b"
        """
        expected = """
        const (
            a = 'test'
            b = 'a' + 'b'
        )
        """
        self.assert_transpilation(code, expected)

if __name__ == '__main__':
    unittest.main()
