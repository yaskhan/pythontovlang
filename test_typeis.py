from typing import TypeIs, Union

def is_str(val: Union[int, str]) -> TypeIs[str]:
    return isinstance(val, str)

def foo(x: Union[int, str]):
    if is_str(x):
        print(x)
    else:
        print(x)
