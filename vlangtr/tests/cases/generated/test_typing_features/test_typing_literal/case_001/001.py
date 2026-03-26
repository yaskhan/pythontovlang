from typing import Literal

def foo(x: Literal[1, 2]) -> Literal['a', 'b']:
    return 'a'
