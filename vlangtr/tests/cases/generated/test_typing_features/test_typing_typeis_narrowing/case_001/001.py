from typing import TypeIs

def is_int(val: int | str) -> TypeIs[int]:
    return isinstance(val, int)

def check(val: int | str):
    if is_int(val):
        print(val)
    else:
        print(val)
