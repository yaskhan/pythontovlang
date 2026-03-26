from typing import overload, Generic, TypeVar, List

T = TypeVar('T')

class UserList(Generic[T]):
    @overload
    def __init__(self, data: List[T]) -> None: ...
    @overload
    def __init__(self, data: None) -> None: ...
    def __init__(self, data: List[T] | None = None) -> None:
        pass
