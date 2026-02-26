
class Base:
    def method(self):
        pass

class TestClass(Base):
    def method(self):
        super().method() # With args (handled previously)
        super() # No args (new support)

def test_del_slice():
    l = [1, 2, 3, 4, 5]
    del l[1:3]
    del l[:1]
    del l[1:]

def test_chained_assign():
    a = b = c = 1

def test_loops():
    for i in range(3):
        pass
    else:
        print("For else")

    while False:
        pass
    else:
        print("While else")

def test_try():
    try:
        print("Try")
    except:
        print("Except")
    else:
        print("Else")
    finally:
        print("Finally")

def test_raise():
    try:
        raise ValueError("Error") from None
    except:
        pass

def test_unpacking():
    l1 = [1, 2]
    l2 = [0, *l1, 3]
    t1 = (1, 2)
    t2 = (*t1, 3)
    s1 = {1, 2}
    s2 = {*s1, 3}

    d1 = {'a': 1}
    d2 = {'b': 2, **d1}
