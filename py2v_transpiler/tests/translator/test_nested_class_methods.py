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
            struct OuterInner {
                x int
            }
        """)
        self.assert_transpilation(source, """
            struct Outer {
            }
        """)
        self.assert_transpilation(source, """
            fn new_outer_inner(x int) &OuterInner {
                mut self := &OuterInner{}
                self.x = x
                return &self
            }
        """)
        self.assert_transpilation(source, """
            fn (self OuterInner) get_x() int {
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
            struct OuterInner {
                val int
            }
        """)
        self.assert_transpilation(source, """
            struct Outer {
            }
        """)
        self.assert_transpilation(source, """
            fn new_outer_inner(val int) &OuterInner {
                mut self := &OuterInner{}
                self.val = val
                return &self
            }
        """)
        self.assert_transpilation(source, """
            fn (self Outer) make_inner(v int) OuterInner {
                return new_outer_inner(v)
            }
        """)
