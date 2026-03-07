from typing import Generic, TypeVar

T = TypeVar("T")

class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x

def main():
    b = Box(10)
    print(b.x)

if __name__ == "__main__":
    main()
