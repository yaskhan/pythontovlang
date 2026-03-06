def test_range_basic():
    r = range(5)
    print(f"range(5): {list(r)}")
    
    r = range(2, 7)
    print(f"range(2, 7): {list(r)}")
    
    r = range(0, 10, 2)
    print(f"range(0, 10, 2): {list(r)}")

def test_range_negative():
    r = range(-5, 0)
    print(f"range(-5, 0): {list(r)}")
    
    r = range(0, -5, -1)
    print(f"range(0, -5, -1): {list(r)}")
    
    r = range(5, -5, -2)
    print(f"range(5, -5, -2): {list(r)}")

def test_range_iteration():
    for i in range(3):
        print(f"i={i}")

def test_range_indexing():
    r = range(10, 20, 2)
    print(f"r[0]: {r[0]}")
    print(f"r[2]: {r[2]}")
    print(f"r[-1]: {r[-1]}")

def test_range_slicing():
    r = range(10)
    sliced = list(r[2:6])
    print(f"r[2:6]: {sliced}")
    
    sliced = list(r[::3])
    print(f"r[::3]: {sliced}")

def test_range_len():
    r = range(100, 200, 5)
    print(f"len(range(100, 200, 5)): {len(r)}")

def test_range_membership():
    r = range(0, 10, 2)
    print(f"4 in r: {4 in r}")
    print(f"5 in r: {5 in r}")

def test_range_conversion():
    r = range(5)
    print(f"list(r): {list(r)}")
    print(f"tuple(r): {tuple(r)}")
    print(f"set(r): {set(r)}")

def test_range_with_enumerate():
    for i, val in enumerate(range(10, 20, 2)):
        print(f"i={i}, val={val}")

def test_range_nested():
    for i in range(3):
        for j in range(3):
            print(f"({i}, {j})", end=" ")
        print()

def test_range_large():
    # range is memory-efficient
    r = range(1000000)
    print(f"range(1000000) size: {len(r)}")
    print(f"range(1000000)[500000]: {r[500000]}")

def test_range_start_stop_step():
    r = range(10, 2, -2)
    print(f"range(10, 2, -2): {list(r)}")

def test():
    test_range_basic()
    test_range_negative()
    test_range_iteration()
    test_range_indexing()
    test_range_slicing()
    test_range_len()
    test_range_membership()
    test_range_conversion()
    test_range_with_enumerate()
    test_range_nested()
    test_range_large()
    test_range_start_stop_step()

if __name__ == "__main__":
    test()
