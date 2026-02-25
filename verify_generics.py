from typing import Generic, TypeVar, Union

T = TypeVar("T")
U = TypeVar("U", int, str)

class Base(Generic[T]):
    def __init__(self, val: T):
        self.val = val

class Child(Base[int]):
    def method(self, x: U) -> U:
        return x
