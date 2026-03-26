from typing import TypeGuard

def is_str(val: object) -> TypeGuard[str]:
    return isinstance(val, str)

def check(val: object):
    if is_str(val):
        print(val)
    else:
        pass
