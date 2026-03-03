from reproduction.nested.models.user import User
class Order:
    def __init__(self, user: User):
        self.user = user
