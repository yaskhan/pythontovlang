from typing import overload

class A:
    @overload
    def __init__(self, x: int) -> None: ...
    def __init__(self, x: int) -> None:
        pass

class B:
    @overload
    def __init__(self, y: str) -> None: ...
    def __init__(self, y: str) -> None:
        pass

a = A(1)
b = B("s")
