import dataclasses
from typing import ClassVar, InitVar

@dataclasses.dataclass
class Point:
    x: int
    y: int = 5
    z: InitVar[int] = 0
    c: ClassVar[int] = 10

p = Point(1, z=3)
