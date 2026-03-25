import pytest
from .utils import TranspilerTest

class TestInterfaceFields(TranspilerTest):
    def test_interface_fields_from_init(self):
        python_code = """
        from typing import Optional

        class Task:
            def __init__(self):
                self.link: Optional['Task'] = None
                self.ident: int = 0

        class SubTask(Task):
            pass
        """
        # We expect link to be ?Task and ident to be int, with no assignments in the interface
        expected_v = """
        interface Task {
            link ?Task
            ident int
        }
        """
        self.assert_transpilation(python_code, expected_v)

    def test_protocol_fields_strip_defaults(self):
        python_code = """
        from typing import Protocol, Optional

        class Handler(Protocol):
            timeout: int = 30
            retry: bool = True
            name: Optional[str] = None
        """
        expected_v = """
        interface Handler {
            timeout int
            retry bool
            name ?string
        }
        """
        self.assert_transpilation(python_code, expected_v)

    def test_generic_struct_field_preservation(self):
        # Regression test for the CI failure found earlier
        python_code = """
        from typing import Generic, TypeVar

        T = TypeVar("T")

        class Box(Generic[T]):
            def __init__(self, x: T):
                self.x = x
        """
        # x should be T, not int (which happened when it relied on a stale type_map)
        # It's pub mut because it's assigned in __init__
        expected_v = """
        struct Box[T] {
        pub mut:
            x T
        }
        """
        self.assert_transpilation(python_code, expected_v)

    def test_interface_field_unannotated_fallback(self):
        python_code = """
        class Base:
            def __init__(self):
                self.value = 1.0

        class Derived(Base):
            pass
        """
        # value should be f64 inferred from 1.0
        expected_v = """
        interface Base {
            value f64
        }
        """
        self.assert_transpilation(python_code, expected_v)
