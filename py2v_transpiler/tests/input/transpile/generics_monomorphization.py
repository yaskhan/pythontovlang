from typing import Generic, TypeVar

T = TypeVar("T")

class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x

def factory(x: int) -> Box[int]:
    return Box(x)

def main():
    b = factory(10)
    print(b.x)

if __name__ == "__main__":
    main()
