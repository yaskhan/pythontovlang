from pydantic import BaseModel
from typing import overload

class User(BaseModel):
    name: str
    age: int

    @overload
    def __init__(self, name: str, age: int) -> None: ...
    @overload
    def __init__(self, name: str) -> None: ...
    def __init__(self, name: str, age: int = 0) -> None:
        self.name = name
        self.age = age
