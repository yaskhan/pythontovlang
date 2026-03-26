def f(x: int | str):
    if isinstance(x, str):
        print(x.upper())
    else:
        print(x + 1)
