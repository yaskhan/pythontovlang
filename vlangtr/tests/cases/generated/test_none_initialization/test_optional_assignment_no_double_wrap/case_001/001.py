def outer(flag: bool) -> None:
    if flag:
        grade = 'A'
    def inner(grade: str) -> None:
        pass
    if not flag:
        grade = 'B'
