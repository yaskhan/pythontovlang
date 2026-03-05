class User:
    def __init__(self, first: str, last: str):
        self._first = first
        self._last = last

def test_underscore_vars():
    _local_var = 10
    print(_local_var)

def test_match_underscore(status):
    match status:
        case 200:
            return "OK"
        case _:
            return "Unknown"
