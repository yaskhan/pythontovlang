def process(data: dict) -> None:
    data['key'] = 'value'

def wrapper(d: dict) -> None:
    process(d)
