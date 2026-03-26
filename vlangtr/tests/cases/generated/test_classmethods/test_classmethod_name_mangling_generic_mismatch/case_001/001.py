from typing import Generic, TypeVar, Any, overload

T = TypeVar('T')

class UserDict(Generic[T]):
    @overload
    @classmethod
    def fromkeys(cls, iterable: T, value: Any = None) -> 'UserDict[T]': ...

    @classmethod
    def fromkeys(cls, iterable: T, value: Any = None) -> 'UserDict[T]':
        return cls()
