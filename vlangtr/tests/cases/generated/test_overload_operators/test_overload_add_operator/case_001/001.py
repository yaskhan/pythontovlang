from typing import overload

class Vector:
    @overload
    def __add__(self, other: 'Vector') -> 'Vector':
        pass

    @overload
    def __add__(self, other: int) -> 'Vector':
        pass

    def __add__(self, other):
        return self
