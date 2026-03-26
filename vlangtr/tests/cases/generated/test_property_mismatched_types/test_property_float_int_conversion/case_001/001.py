class Measurement:
    _value: float = 0.0

    def __init__(self):
        self._value = 0.0

    @property
    def value(self) -> float:
        return self._value

    @value.setter
    def value(self, new_value: int | float):
        self._value = float(new_value)
