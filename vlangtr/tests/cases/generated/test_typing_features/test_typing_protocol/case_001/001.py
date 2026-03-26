from typing import Protocol

class Proto(Protocol):
    def method(self, x: int) -> int:
        ...
