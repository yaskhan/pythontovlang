import functools
@functools.lru_cache(maxsize=None)
def fib(n):
    return n
