from typing import get_type_hints

class A:
    x: int
    y: str

def main():
    print(get_type_hints(A))

if __name__ == "__main__":
    main()
