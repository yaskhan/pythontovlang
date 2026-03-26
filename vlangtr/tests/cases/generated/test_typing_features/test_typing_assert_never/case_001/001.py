from typing import assert_never

def check(x: int) -> None:
    if x == 1:
        pass
    else:
        assert_never(x)
