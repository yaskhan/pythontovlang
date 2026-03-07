
from typing import Generic, TypeVar, List

T = TypeVar("T")

class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x

def main():
    items = [Box(10), Box(20)]
    print(items)
