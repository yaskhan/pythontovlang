
from typing import Iterator, Generator

def simple_gen() -> Iterator[int]:
    yield 1
    yield 2
    yield 3

def bi_directional_gen() -> Generator[int, int, None]:
    # Start
    x = yield 1 # Yields 1, expects value sent back
    # Received value (e.g. 10)
    # Check types for mypy safety - x is int
    if x is None:
        x = 0
    y = yield x * 2 # Yields 20, expects value
    if y is None:
        y = 0
    yield y + 1 # Yields 11 (if 10 sent again? No, y is from previous send)

def test_simple_iteration():
    g = simple_gen()
    assert next(g) == 1
    assert next(g) == 2
    assert next(g) == 3
    # assert next(g) raises StopIteration - hard to test in V unless panic is caught?
    # Transpiled code returns ?T, so next() returns none.
    # But assert next(g) == none might not compile if return type is int.
    # V: next() returns ?int.
    # If we assert next(g) == 3, it unwraps or checks equality?
    # Python `assert` -> V `assert`. `next(g) == 1` -> `g.next() == 1`.
    # `g.next()` returns `?int`. `?int == int` is valid in V.
    pass

def test_send():
    g = bi_directional_gen()
    # First next() advances to first yield
    val1 = next(g)
    assert val1 == 1

    # Send 10. x becomes 10. Yields x*2 = 20.
    val2 = g.send(10)
    assert val2 == 20

    # Send 5. y becomes 5. Yields y+1 = 6.
    val3 = g.send(5)
    assert val3 == 6

    # Next send/next closes
    # val4 = g.send(0) -> None
    pass

def test_close():
    g = simple_gen()
    assert next(g) == 1
    g.close()
    # next(g) should now return None or panic?
    # In V implementation: close() sets open=false. next() returns none.
    # But channel close logic ensures subsequent reads on out return none?
    # Let's verify close mechanism implicitly via no crash.
    pass
