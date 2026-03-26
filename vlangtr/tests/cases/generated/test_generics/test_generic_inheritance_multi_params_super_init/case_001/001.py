from typing import Generic, TypeVar

K = TypeVar('K')
V = TypeVar('V')

class Base(Generic[K, V]):
    def __init__(self, k: K, v: V):
        self.k = k
        self.v = v

class Derived(Base[str, int]):
    def __init__(self, k: str, v: int):
        super().__init__(k, v)
