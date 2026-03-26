from typing import Generic, TypeVar, Any
from abc import ABC, abstractclassmethod

T = TypeVar('T')

class UserDict(Generic[T], ABC):
    @abstractclassmethod
    def fromkeys(cls, iterable: T, value: Any = None) -> 'UserDict[T]': ...
