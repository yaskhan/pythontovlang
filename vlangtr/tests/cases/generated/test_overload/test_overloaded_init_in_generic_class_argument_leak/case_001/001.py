from typing import overload, Generic, TypeVar

T = TypeVar('T')

class Container(Generic[T]):
    @overload
    def __init__(self, item: T) -> None: ...
    @overload
    def __init__(self, item: int) -> None: ...
    def __init__(self, item: T | int) -> None:
        pass
