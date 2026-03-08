from typing import Literal, TypedDict

class User(TypedDict):
    name: str
    age: int

def test_loop_narrowing(u: User):
    keys = ("name", "age")
    for key in keys:
        if key in u:
            print(u[key])
