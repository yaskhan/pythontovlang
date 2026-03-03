from reproduction.nested.models.order import Order
class User:
    def __init__(self, order: Order):
        self.order = order
