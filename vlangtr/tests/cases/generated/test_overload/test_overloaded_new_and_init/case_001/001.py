from typing import overload

class Multi:
    @overload
    def __new__(cls, x: int) -> "Multi": ...
    @overload
    def __new__(cls, x: str) -> "Multi": ...
    def __new__(cls, x: int | str) -> "Multi":
        return object.__new__(cls)

    @overload
    def __init__(self, x: int) -> None: ...
    @overload
    def __init__(self, x: str) -> None: ...
    def __init__(self, x: int | str) -> None:
        pass

m1 = Multi(1)
m2 = Multi("a")
