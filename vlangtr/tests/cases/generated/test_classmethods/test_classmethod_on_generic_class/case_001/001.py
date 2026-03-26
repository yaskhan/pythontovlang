from typing import Generic, TypeVar, Any

T = TypeVar('T')

class UserDict(Generic[T]):
    @classmethod
    def fromkeys(cls, iterable: Any, value: Any = None) -> 'UserDict[T]':
        """Create new instance from iterable."""
        return cls()
