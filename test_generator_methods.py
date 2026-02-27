
def my_gen():
    x = yield 1
    yield x + 1

def test_send():
    g = my_gen()
    # First yield (1)
    # val1 = next(g)
    # assert val1 == 1
    # # Send 2, assign to x, yield x+1 (3)
    # val2 = g.send(2)
    # assert val2 == 3
    pass
