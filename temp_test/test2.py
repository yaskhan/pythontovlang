
from typing import Literal, TypedDict
class User(TypedDict):
    name: str
    age: int

def test(u: User):
    for key in ('name', 'age'):
        print(key)
