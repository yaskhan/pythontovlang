def process(lst: list) -> None:
    lst.append(1)

def wrapper(l: list) -> None:
    process(l)
