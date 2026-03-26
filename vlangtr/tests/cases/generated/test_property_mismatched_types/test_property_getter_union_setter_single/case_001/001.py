class Result:
    _value: int = 0

    def __init__(self):
        self._value = 0

    @property
    def value(self) -> int | str:
        return self._value

    @value.setter
    def value(self, new_value: int):
        self._value = new_value
