from typing import overload, Generic, TypeVar

T = TypeVar('T')

class UserDict(Generic[T]):
    @overload
    def __init__(self, data: dict) -> None: ...
    @overload
    def __init__(self, data: None) -> None: ...
    def __init__(self, data: dict | None = None) -> None:
        pass
