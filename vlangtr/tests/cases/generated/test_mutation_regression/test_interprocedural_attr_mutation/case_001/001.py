class Data:
    def __init__(self):
        self.val = 0

def modify(obj: Data) -> None:
    obj.val = 1

def wrapper(obj: Data) -> None:
    modify(obj)
