from functools import lru_cache

@lru_cache(maxsize=None)
def fib(n) -> int:
    return n
