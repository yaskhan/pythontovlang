class Plan:
    def __init__(self, constraints: list[int]):
        self.constraints = constraints

    def __len__(self) -> int:
        return len(self.constraints)

    def __getitem__(self, index: int) -> int:
        return self.constraints[index]
