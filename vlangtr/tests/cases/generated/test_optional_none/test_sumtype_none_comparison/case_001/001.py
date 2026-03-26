from typing import Union
class A: pass
class B: pass
def run(work: Union[A, B, None]):
    if work is None:
        return
    print(work)
