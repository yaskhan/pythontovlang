from typing import TypedDict, ReadOnly

class MyDict(TypedDict):
    a: int
    b: ReadOnly[str]
    c: float
