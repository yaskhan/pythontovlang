from typing import overload

class Calculator:
    @overload
    def add(self, x: int) -> int: ...
    @overload
    def add(self, x: str) -> str: ...
    def add(self, x: int | str) -> int | str:
        return x

c = Calculator()
r1 = c.add(1)
r2 = c.add("s")
