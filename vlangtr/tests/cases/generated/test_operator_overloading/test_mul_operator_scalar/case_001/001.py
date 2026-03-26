class Vector:
    def __mul__(self, scalar: int) -> 'Vector':
        return Vector(self.x * scalar, self.y * scalar)
