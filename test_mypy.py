
from typing import Union

class A:
    def draw(self): pass

class B:
    pass

def foo(obj: Union[A, B], obj2: A):
    if hasattr(obj, "draw"):
        pass
    if hasattr(obj2, "draw"):
        pass
    if hasattr(obj, "other"):
        pass
