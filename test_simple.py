
from typing import TypedDict
class D(TypedDict):
    a: int

def t(d: D):
    for k in ('a',):
        print(d[k])
