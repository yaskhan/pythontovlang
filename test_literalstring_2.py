def foo():
    from typing import LiteralString

    a: LiteralString = "test"
    b: LiteralString = "a" + "b"
    c: LiteralString = f"{a}b"
    d: LiteralString = input()
