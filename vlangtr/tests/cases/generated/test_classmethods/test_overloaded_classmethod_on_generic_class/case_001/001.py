from typing import Generic, TypeVar, Any, Iterable, overload

T = TypeVar('T')

class UserDict(Generic[T]):
    @overload
    @classmethod
    def fromkeys(cls, iterable: Iterable[T]) -> 'UserDict[T]': ...

    @classmethod
    def fromkeys(cls, iterable: Any, value: Any = None) -> 'UserDict[T]':
        return cls()
