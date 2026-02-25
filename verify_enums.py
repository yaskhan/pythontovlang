from enum import IntEnum, Enum

class Color(IntEnum):
    RED = 1
    GREEN = 2
    BLUE = 3

class Status(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
