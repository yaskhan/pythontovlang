from dataclasses import dataclass

@dataclass(frozen=True)
class FrozenPoint:
    x: int

p = FrozenPoint(1)
