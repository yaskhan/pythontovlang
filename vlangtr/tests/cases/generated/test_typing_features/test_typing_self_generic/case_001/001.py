from typing import Self

class Builder[T]:
    def set_value(self, value: T) -> Self:
        return self
