class Constraint:
    pass

class Variable:
    pass

OrderedCollection = list

def foo():
    a = OrderedCollection()
    a.append(Constraint())
    return a

def bar():
    b = OrderedCollection()
    b.append(Variable())
    return b
