def f(flag: bool) -> None:
    other: Optional[str] = None
    if flag:
        grade = 'A'
    if other is not None:
        grade = 'B'
