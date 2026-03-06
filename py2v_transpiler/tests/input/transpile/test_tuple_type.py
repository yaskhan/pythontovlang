def test_tuple_creation():
    t1 = (1, 2, 3)
    print(f"Tuple: {t1}")
    
    t2 = 1, 2, 3
    print(f"Without parens: {t2}")
    
    t3 = tuple([1, 2, 3])
    print(f"From list: {t3}")
    
    # Single element tuple
    t4 = (1,)
    print(f"Single element: {t4}")
    
    # Empty tuple
    t5 = ()
    print(f"Empty tuple: {t5}")

def test_tuple_access():
    t = (10, 20, 30, 40, 50)
    print(f"t[0]: {t[0]}")
    print(f"t[-1]: {t[-1]}")
    print(f"t[1:4]: {t[1:4]}")
    print(f"t[::2]: {t[::2]}")

def test_tuple_unpacking():
    t = (1, 2, 3)
    a, b, c = t
    print(f"a={a}, b={b}, c={c}")
    
    # Nested unpacking
    nested = (1, (2, 3), 4)
    x, (y, z), w = nested
    print(f"x={x}, y={y}, z={z}, w={w}")

def test_tuple_immutable():
    t = (1, 2, 3)
    # t[0] = 10  # Would raise TypeError
    print(f"Tuple is immutable: {t}")
    
    # But can contain mutable objects
    t2 = ([1, 2], [3, 4])
    t2[0].append(3)
    print(f"Mutable inside tuple: {t2}")

def test_tuple_methods():
    t = (1, 2, 3, 2, 4, 2, 5)
    print(f"Count of 2: {t.count(2)}")
    print(f"Index of 4: {t.index(4)}")

def test_tuple_concat():
    t1 = (1, 2, 3)
    t2 = (4, 5, 6)
    result = t1 + t2
    print(f"Concat: {result}")

def test_tuple_repeat():
    t = (1, 2)
    result = t * 3
    print(f"Repeat: {result}")

def test_tuple_membership():
    t = (1, 2, 3, 4, 5)
    print(f"3 in tuple: {3 in t}")
    print(f"10 not in tuple: {10 not in t}")

def test_tuple_comparison():
    t1 = (1, 2, 3)
    t2 = (1, 2, 4)
    t3 = (1, 2, 3)
    
    print(f"t1 == t3: {t1 == t3}")
    print(f"t1 < t2: {t1 < t2}")
    print(f"t1 > t2: {t1 > t2}")

def test_named_tuple():
    from collections import namedtuple
    
    Point = namedtuple("Point", ["x", "y"])
    p = Point(3, 4)
    
    print(f"Point: {p}")
    print(f"p.x: {p.x}")
    print(f"p.y: {p.y}")
    print(f"p[0]: {p[0]}")
    
    # Unpack
    x, y = p
    print(f"Unpacked: x={x}, y={y}")

def test_tuple_as_dict_key():
    # Tuples can be dict keys (if elements are hashable)
    d = {(0, 0): "origin", (1, 1): "diagonal"}
    print(f"Dict with tuple keys: {d}")
    print(f"d[(0, 0)]: {d[(0, 0)]}")

def test_tuple_function_return():
    def get_min_max(nums):
        return min(nums), max(nums)
    
    result = get_min_max([3, 1, 4, 1, 5, 9])
    print(f"Min and max: {result}")
    
    min_val, max_val = get_min_max([3, 1, 4, 1, 5, 9])
    print(f"Unpacked: min={min_val}, max={max_val}")

def test():
    test_tuple_creation()
    test_tuple_access()
    test_tuple_unpacking()
    test_tuple_immutable()
    test_tuple_methods()
    test_tuple_concat()
    test_tuple_repeat()
    test_tuple_membership()
    test_tuple_comparison()
    test_named_tuple()
    test_tuple_as_dict_key()
    test_tuple_function_return()

if __name__ == "__main__":
    test()
