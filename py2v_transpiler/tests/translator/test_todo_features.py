from .utils import TranspilerTest

class TestTodoFeatures(TranspilerTest):
    def test_legacy_string_formatting(self):
        self.assert_transpilation(
            "x = 'Value: %d' % 10",
            """
            x := py_string_format('Value: %d', 10)
            """
        )
        self.assert_transpilation(
            "x = 'Name: %s, Age: %d' % ('Alice', 30)",
            """
            x := py_string_format('Name: %s, Age: %d', 'Alice', 30)
            """
        )

    def test_raw_string_literals(self):
        # We need to be careful with python string escaping in test definition
        self.assert_transpilation(
            "x = r'C:\\Windows\\System32'",
            """
            x := r'C:\\Windows\\System32'
            """
        )

    def test_variable_annotations(self):
        self.assert_transpilation(
            """
            x: int
            y: float
            z: str
            b: bool
            l: list
            d: dict
            """,
            """
            x := 0
            y := 0.0
            z := ''
            b := false
            l := []int{}
            d := map[string]int{}
            """
        )

    def test_f_string_debug(self):
        self.assert_transpilation(
            "x = 10\ns = f'{x=}'",
            """
            mut x := 10
            mut s := 'x=${x}'
            """
        )

    def test_multiple_context_managers(self):
        # A() and B() are treated as function calls because they are not defined as classes in the snippet.
        self.assert_transpilation(
            """
            with A() as a, B() as b:
                pass
            """,
            """
            a := A()
            defer { a.close() }
            b := B()
            defer { b.close() }
            """
        )

    def test_slice_assignment(self):
        self.assert_transpilation(
            """
            l = [1, 2, 3, 4]
            l[1:3] = [5, 6]
            """,
            """
            mut l := [1, 2, 3, 4]
            l.delete_many(1, (3) - (1))
            l.insert_many(1, [5, 6])
            """
        )

    def test_nested_classes(self):
        # Transpiler emits nested structs first due to visitation order (depth-first)
        self.assert_transpilation(
            """
            class Outer:
                class Inner:
                    pass
            """,
            """
            struct Outer_Inner {
            }
            struct Outer {
            }
            """
        )
