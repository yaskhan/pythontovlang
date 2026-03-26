from typing import TypedDict, ReadOnly

class MyDict(TypedDict):
    a: int
    b: ReadOnly[str]

d: MyDict = {"a": 1, "b": "hello"}
d.b = "world"
