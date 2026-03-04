from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestFString312Extra(TranspilerTest):
    def test_fstring_312_complex_format_spec_with_expr(self):
        py_code = """
        width = 10
        x = 42
        print(f"{x:{width}.2f}")
        """
        self.assert_transpilation(py_code, "println('${py_format(x, \"${width}.2f\")}')")

    def test_fstring_312_nested_double(self):
        py_code = """
        x = 42
        s = f"{f'{f\"{x}\"}'}"
        """
        # Outer: '
        # Inner 1: "
        # Inner 2: '
        self.assert_transpilation(py_code, "s := '${" + '"${\'${x}\'}"' + "}'")

    def test_fstring_312_debug_with_spaces(self):
        py_code = """
        x = 10
        print(f"{  x  =  }")
        """
        # Python 3.12+ might include spaces in Constant part
        self.assert_transpilation(py_code, "println('  x  =  ${py_repr(x)}')")
