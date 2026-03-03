
import dataclasses
from typing import InitVar

@dataclasses.dataclass
class Point:
    x: int
    y: int
    z: InitVar[int] = 0

p = Point(1, 2, 3)
