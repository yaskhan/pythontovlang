from typing import overload

@overload
def foo(x: int) -> int:
    ...

@overload
def foo(x: str) -> str:
    ...

def foo(x):
    return x
