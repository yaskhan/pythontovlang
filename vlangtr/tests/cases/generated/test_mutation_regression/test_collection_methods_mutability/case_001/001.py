def test_dict(d: dict):
    d.update({'a': 1})
    d.pop('b')
    d.clear()

def test_list(l: list):
    l.insert(0, 1)
    l.extend([2, 3])
    l.remove(1)
    l.pop()

def test_set(s: set):
    s.add(1)
    s.discard(2)
