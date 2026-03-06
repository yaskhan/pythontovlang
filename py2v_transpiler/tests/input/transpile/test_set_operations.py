def test_set_creation():
    # Literal syntax
    s1 = {1, 2, 3, 4}
    print(s1)
    
    # Empty set
    s2 = set()
    print(f"Empty set: {s2}")
    
    # From list
    s3 = set([1, 2, 2, 3, 3, 3])
    print(f"From list: {s3}")

def test_set_add_remove():
    s = {1, 2, 3}
    s.add(4)
    print(f"After add: {s}")
    
    s.remove(2)
    print(f"After remove: {s}")
    
    s.discard(10)  # No error if not exists
    print(f"After discard: {s}")
    
    popped = s.pop()
    print(f"Popped: {popped}, Set: {s}")

def test_set_operations():
    a = {1, 2, 3, 4, 5}
    b = {4, 5, 6, 7, 8}
    
    # Union
    print(f"Union: {a | b}")
    print(f"Union method: {a.union(b)}")
    
    # Intersection
    print(f"Intersection: {a & b}")
    print(f"Intersection method: {a.intersection(b)}")
    
    # Difference
    print(f"Difference a-b: {a - b}")
    print(f"Difference b-a: {b - a}")
    
    # Symmetric difference
    print(f"Symmetric diff: {a ^ b}")

def test_set_update_operations():
    a = {1, 2, 3}
    b = {3, 4, 5}
    
    a.update(b)
    print(f"After update: {a}")
    
    a = {1, 2, 3}
    a.intersection_update(b)
    print(f"After intersection_update: {a}")
    
    a = {1, 2, 3}
    a.difference_update(b)
    print(f"After difference_update: {a}")
    
    a = {1, 2, 3}
    a.symmetric_difference_update(b)
    print(f"After symmetric_difference_update: {a}")

def test_set_subset_superset():
    a = {1, 2, 3, 4, 5}
    b = {2, 3, 4}
    
    print(f"b is subset of a: {b.issubset(a)}")
    print(f"a is superset of b: {a.issuperset(b)}")
    print(f"b <= a: {b <= a}")
    print(f"a >= b: {a >= b}")

def test_set_clear_copy():
    s = {1, 2, 3}
    s_copy = s.copy()
    print(f"Copy: {s_copy}")
    
    s.clear()
    print(f"After clear: {s}")
    print(f"Copy after clear: {s_copy}")

def test_set_membership():
    s = {10, 20, 30}
    print(f"20 in s: {20 in s}")
    print(f"40 not in s: {40 not in s}")

def test_frozenset():
    fs = frozenset([1, 2, 3])
    print(f"Frozenset: {fs}")
    
    # fs.add(4)  # Would raise AttributeError

def test():
    test_set_creation()
    test_set_add_remove()
    test_set_operations()
    test_set_update_operations()
    test_set_subset_superset()
    test_set_clear_copy()
    test_set_membership()
    test_frozenset()

if __name__ == "__main__":
    test()
