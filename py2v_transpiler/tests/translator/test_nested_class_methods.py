import textwrap
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
            pub:
                x int
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
            pub:
                val int
            }
        """)
