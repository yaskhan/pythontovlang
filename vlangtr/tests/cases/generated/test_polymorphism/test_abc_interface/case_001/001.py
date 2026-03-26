from abc import ABC, abstractmethod

class Constraint(ABC):
    @abstractmethod
    def satisfy(self, value: int) -> bool:
        pass

class UnaryConstraint(Constraint):
    def satisfy(self, value: int) -> bool:
        return value > 0
