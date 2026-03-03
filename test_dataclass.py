import dataclasses
from typing import ClassVar

@dataclasses.dataclass
class Point:
    x: int
    y: int = 5
    z: dataclasses.InitVar[int] = 0
    c: ClassVar[int] = 10

p = Point(1)
