from abc import ABC, abstractmethod

class BaseConstraint(ABC):
    pass

class Constraint(BaseConstraint):
    @abstractmethod
    def satisfy(self, value: int) -> bool:
        pass

class UnaryConstraint(Constraint):
    def satisfy(self, value: int) -> bool:
        return value > 0

class Intermediate(Constraint):
    pass
