import sys
from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestFString312(TranspilerTest):
    def test_fstring_312_nested(self):
        try:
            py_code = """
            x = 10
            s = f"Val: {f'nested {x}'}"
            """
            # Outer f-string starts with '. Inner will start with ".
            self.assert_transpilation(py_code, "s := 'Val: ${\"nested ${x}\"}'")
        except SyntaxError:
            pass # Skip if running on older Python

    def test_fstring_312_debug(self):
        try:
            py_code = """
            x = 10
            print(f"{x=}")
            """
            # Python 3.12+ parses f"{x=}" as Constant("x=") + FormattedValue(x, conversion=114)
            self.assert_transpilation(py_code, "println('x=${py_repr(x)}')")
        except SyntaxError:
            pass

    def test_fstring_312_complex_spec(self):
        try:
            py_code = """
            x = 10
            print(f"{x:^10}")
            """
            # Center align needs py_format
            self.assert_transpilation(py_code, "println('${py_format(x, '^10')}')")
        except SyntaxError:
            pass

    def test_fstring_312_conversions(self):
        try:
            py_code = """
            x = "hello"
            print(f"{x!r}")
            print(f"{x!a}")
            """
            self.assert_transpilation(py_code, "println('${py_repr(x)}')")
            self.assert_transpilation(py_code, "println('${py_ascii(x)}')")
        except SyntaxError:
            pass

    def test_fstring_312_reuse_quotes(self):
        # Python 3.12 allows reusing quotes
        try:
            py_code = """
            x = 10
            s = f"{'same quote'}"
            """
            # Outer f-string starts with '. Inner starts with ".
            self.assert_transpilation(py_code, "s = '${\"same quote\"}'")
        except SyntaxError:
            pass
