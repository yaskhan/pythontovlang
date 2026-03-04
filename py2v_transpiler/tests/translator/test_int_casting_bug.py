from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestIntCastingBug(TranspilerTest):
    def test_int_input_casting(self):
        # This currently fails by producing 'number := int{os.input('Prompt: ')}'
        # if the analyzer somehow thinks 'int' is a class (which it is in Python).
        # We want it to be 'number := os.input('Prompt: ').int()' or 'int(os.input(...))'
        self.assert_transpilation(
            "number = int(input('Prompt: '))",
            "number := os.input('Prompt: ').int()"
        )

    def test_float_casting(self):
        self.assert_transpilation(
            "val = float('3.14')",
            "val := '3.14'.f64()"
        )

    def test_bool_casting(self):
        self.assert_transpilation(
            "val = bool(1)",
            "val := (1 != 0)"
        )

    def test_str_casting(self):
        self.assert_transpilation(
            "val = str(42)",
            "val := 42.str()"
        )
