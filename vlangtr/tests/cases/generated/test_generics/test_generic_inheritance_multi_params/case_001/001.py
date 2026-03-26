from typing import Generic, TypeVar

K = TypeVar('K')
V = TypeVar('V')

class Base(Generic[K, V]):
    pass

class Derived(Base[K, V]):
    pass
