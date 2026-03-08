from typing import Literal, TypedDict
class User(TypedDict):
    name: str
    age: int

def test_narrowing(u: User) -> None:
    for my_very_unique_key in ("name", "age"):
        print(u[my_very_unique_key])
