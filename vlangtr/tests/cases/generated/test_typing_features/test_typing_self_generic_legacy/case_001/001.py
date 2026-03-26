from typing import Self, TypeVar, Generic

T = TypeVar("T")

class Builder(Generic[T]):
    def set_value(self, value: T) -> Self:
        return self
