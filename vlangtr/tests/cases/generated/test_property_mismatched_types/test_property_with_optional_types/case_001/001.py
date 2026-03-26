from typing import Optional

class DataHolder:
    _data: Optional[str] = None

    def __init__(self):
        self._data = None

    @property
    def data(self) -> Optional[str]:
        return self._data

    @data.setter
    def data(self, value: str | None):
        self._data = value
