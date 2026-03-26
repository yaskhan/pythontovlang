class Box:
    def __eq__(self, other: 'Box') -> bool:
        return self.val == other.val
