from typing import Protocol, TypeVar

T = TypeVar('T')
U = TypeVar('U')

class Iterable(Protocol[T]):
    def __iter__(self): ...

class Awaitable(Protocol[T, U]):
    def __await__(self): ...
