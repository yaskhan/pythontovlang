import pytest
from py2v_transpiler.tests.translator.utils import TranspilerTest

class TestGenericsFields(TranspilerTest):
    def test_generic_field_type_preserved(self):
        python_code = """
        from typing import Generic, TypeVar

        T = TypeVar("T")

        class Box(Generic[T]):
            def __init__(self, x: T):
                self.x = x
        """
        # We expect x to have type T
        # Assigned in __init__ -> pub mut
        expected_v = """
        struct Box[T] {
        pub mut:
            x T
        }
        """
        self.assert_transpilation(python_code, expected_v)

    def test_generic_field_type_multiple_generics(self):
        python_code = """
        from typing import Generic, TypeVar

        T = TypeVar("T")
        U = TypeVar("U")

        class Pair(Generic[T, U]):
            def __init__(self, first: T, second: U):
                self.first = first
                self.second = second
        """
        expected_v = """
        struct Pair[T, U] {
        pub mut:
            first T
            second U
        }
        """
        self.assert_transpilation(python_code, expected_v)

    def test_generic_field_type_preserved_with_shadowing(self):
        python_code = """
        from typing import Generic, TypeVar

        T = TypeVar("T")

        class Box(Generic[T]):
            def __init__(self, x: T):
                self.x = x

        def factory(x: int):
            pass
        """
        expected_v = """
        struct Box[T] {
        pub mut:
            x T
        }
        """
        self.assert_transpilation(python_code, expected_v)

    def test_generic_field_type_unannotated_assign(self):
        python_code = """
        from typing import Generic, TypeVar

        T = TypeVar("T")

        class Box(Generic[T]):
            def __init__(self, x: T):
                y = x
                self.x = y
        """
        expected_v = """
        struct Box[T] {
        pub mut:
            x T
        }
        """
        self.assert_transpilation(python_code, expected_v)
