x = {'a': 1, 'b': 2}
match x:
    case {'a': 1, **rest}:
        pass
