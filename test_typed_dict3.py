from typing import TypedDict

class MyDict(TypedDict):
    a: int
    b: str

d: MyDict = {"a": 1, "b": "hello"}
d["a"] = 2
