from typing import Literal, TypedDict
class User(TypedDict):
    name: str
    age: int

def test(u: User) -> None:
    for k in ('name', 'age'):
        print(u[k])
