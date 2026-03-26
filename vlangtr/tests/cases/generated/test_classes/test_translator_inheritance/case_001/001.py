class Base:
    def __init__(self, x: int):
        self.x = x

class Derived(Base):
    def __init__(self, x: int, y: int):
        super().__init__(x)
        self.y = y
