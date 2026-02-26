from typing import TypedDict, List
import typing

# 1. Augmented matrix multiplication
class Matrix:
    def __init__(self, v): self.v = v
    def matmul(self, other): return Matrix(self.v * other.v)

m = Matrix(2)
m @= Matrix(3)

# 2. Custom __format__
class Formattable:
    def __format__(self, spec):
        return f"Formatted: {spec}"

f = Formattable()
s = f"{f:spec}"

# 3. Bytes formatting
b = b"%s" % b"a"

# 4. Function attributes
def my_func():
    pass
my_func.attr = 10
print(my_func.attr)

# 5. Recursive type aliases
RecursiveList = List['RecursiveList']

# 6. TypedDict class-based
class MyDict(TypedDict):
    x: int
    y: str
