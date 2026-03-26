from typing import TypedDict

class MyDict(TypedDict):
    a: int
    b: str

class MyDict2(TypedDict, total=False):
    a: int
    b: str

d: MyDict = {"a": 1, "b": "hello"}
d["a"] = 2
d["b"] = "world"
print(d["a"])
