
from typing import Iterator

def my_gen() -> Iterator[int]:
    x = yield 1
    yield x + 1

def usage():
    g = my_gen()
    val = next(g)
    val2 = g.send(2)
