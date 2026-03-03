from typing import LiteralString
def foo():
    a: LiteralString = "test"
    b: LiteralString = "a" + "b"
    c: LiteralString = f"{a}b"
    d: LiteralString = input()

e: LiteralString = "test"
f: LiteralString = input()
