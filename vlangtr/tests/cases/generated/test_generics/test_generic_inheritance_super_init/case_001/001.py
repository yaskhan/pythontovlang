from typing import Generic, TypeVar

T = TypeVar('T')

class Base(Generic[T]):
    def __init__(self, x: T):
        self.x = x

class Derived(Base[int]):
    def __init__(self, x: int, y: int):
        super().__init__(x)
        self.y = y
