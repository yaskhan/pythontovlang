def test(data: dict[str, list[int]]):
    result = []
    for values in data.values():
        result.extend(values)
    return result
