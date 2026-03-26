from functools import lru_cache

class Calc:
    @lru_cache
    def add(self, a, b) -> int:
        return a + b
