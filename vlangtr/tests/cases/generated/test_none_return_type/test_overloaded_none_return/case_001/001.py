from typing import overload

@overload
def foo(x: int) -> None: ...
@overload
def foo(x: str) -> None: ...

def foo(x):
    pass
