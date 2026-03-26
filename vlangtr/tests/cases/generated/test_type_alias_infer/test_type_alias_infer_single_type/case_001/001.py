class Constraint:
    pass

OrderedCollection = list

def foo():
    a = OrderedCollection()
    a.append(Constraint())
    return a
