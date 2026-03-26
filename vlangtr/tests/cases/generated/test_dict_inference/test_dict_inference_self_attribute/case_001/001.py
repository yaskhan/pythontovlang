class Node:
    def __init__(self):
        self.children = {}

    def add(self):
        self.children["a"] = Node()

head = Node()
head.children["a"] = Node()
dict1 = {}
dict1["a"] = Node()
