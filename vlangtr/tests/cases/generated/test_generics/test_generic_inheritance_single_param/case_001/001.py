from typing import Generic, TypeVar

T = TypeVar('T')

class Base(Generic[T]):
    pass

class Derived(Base[T]):
    pass
