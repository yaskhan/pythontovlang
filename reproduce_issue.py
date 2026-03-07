class User:
    def __init__(self, _first: str):
        self._first = _first

def test_match():
    status = 200
    match status:
        case 200:
            _match_subject_1 = "ok"
            print(_match_subject_1)
