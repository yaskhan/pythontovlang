from .utils import TranspilerTest

class TestNestedClassMethods(TranspilerTest):
    def test_nested_class_with_methods(self):
        source = """
            class Outer:
                class Inner:
                    def __init__(self, x: int):
                        self.x = x
                    def get_x(self) -> int:
                        return self.x
        """
        self.assert_transpilation(source, """
            struct Outer_Inner {
                x int
            }
        """)
        self.assert_transpilation(source, """
            struct Outer {
            }
        """)
        self.assert_transpilation(source, """
            fn new_outer_inner(x int) Outer_Inner {
                mut self := Outer_Inner{}
                self.x = x
                return self
            }
        """)
        self.assert_transpilation(source, """
            fn (self Outer_Inner) get_x() int {
                return self.x
            }
        """)

    def test_nested_class_factory_usage(self):
        source = """
            class Outer:
                class Inner:
                    def __init__(self, val: int):
                        self.val = val
                def make_inner(self, v: int) -> Inner:
                    return self.Inner(v)
        """
        self.assert_transpilation(source, """
            struct Outer_Inner {
                val int
            }
        """)
        self.assert_transpilation(source, """
            struct Outer {
            }
        """)
        self.assert_transpilation(source, """
            fn new_outer_inner(val int) Outer_Inner {
                mut self := Outer_Inner{}
                self.val = val
                return self
            }
        """)
        self.assert_transpilation(source, """
            fn (self Outer) make_inner(v int) Outer_Inner {
                return new_outer_inner(v)
            }
        """)
