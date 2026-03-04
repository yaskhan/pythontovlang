import sys
from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestFString312(TranspilerTest):
    def test_fstring_312_nested(self):
        py_code = """
        x = 10
        s = f"Val: {f'nested {x}'}"
        """
        # Outer f-string starts with '. Inner will start with ".
        self.assert_transpilation(py_code, "s := 'Val: ${\"nested ${x}\"}'")

    def test_fstring_312_debug(self):
        py_code = """
        x = 10
        print(f"{x=}")
        """
        # Python 3.12+ parses f"{x=}" as Constant("x=") + FormattedValue(x, conversion=114)
        self.assert_transpilation(py_code, "println('x=${py_repr(x)}')")

    def test_fstring_312_complex_spec(self):
        py_code = """
        x = 10
        print(f"{x:^10}")
        """
        # Center align needs py_format
        self.assert_transpilation(py_code, "println('${py_format(x, '^10')}')")

    def test_fstring_312_conversions(self):
        py_code = """
        x = "hello"
        print(f"{x!r}")
        print(f"{x!a}")
        """
        self.assert_transpilation(py_code, "println('${py_repr(x)}')")
        self.assert_transpilation(py_code, "println('${py_ascii(x)}')")

    def test_fstring_312_reuse_quotes(self):
        # Python 3.12 allows reusing quotes
        py_code = """
        x = 10
        s = f"{'same quote'}"
        """
        # Outer f-string starts with '. Inner starts with ".
        self.assert_transpilation(py_code, "s = '${\"same quote\"}'")
