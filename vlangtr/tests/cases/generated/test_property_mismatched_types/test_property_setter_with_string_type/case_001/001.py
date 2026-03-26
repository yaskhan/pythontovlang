class Converter:
    _count: int = 0

    def __init__(self):
        self._count = 0

    @property
    def count(self) -> int:
        return self._count

    @count.setter
    def count(self, value: str):
        self._count = int(value)
