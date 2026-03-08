from typing import Literal, TypedDict
class User(TypedDict):
    name: str
    age: int
def test(u: User) -> None:
    for key in ('name', 'age'):
        print(u[key])
