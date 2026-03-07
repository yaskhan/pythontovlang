from typing import Generic, TypeVar, Dict, List

T = TypeVar("T")
U = TypeVar("U")

class Pair(Generic[T, U]):
    def __init__(self, first: T, second: U):
        self.first = first
        self.second = second

class Container(Generic[T]):
    def __init__(self, items: List[T]):
        self.items = items

def main():
    p = Pair(1, "hello")
    c = Container([1.5, 2.5])

    # Nested generics
    nested = Container([Box(10), Box(20)])

    print(p.first)
    print(p.second)
    print(c.items[0])

class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x

if __name__ == "__main__":
    main()
