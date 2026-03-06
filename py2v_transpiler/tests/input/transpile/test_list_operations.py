def test_list_append_extend():
    lst = [1, 2, 3]
    lst.append(4)
    print(lst)
    
    lst.extend([5, 6, 7])
    print(lst)

def test_list_insert_remove():
    lst = [1, 2, 4, 5]
    lst.insert(2, 3)  # Insert at index
    print(lst)
    
    lst.remove(3)  # Remove by value
    print(lst)

def test_list_pop_clear():
    lst = [10, 20, 30, 40]
    popped = lst.pop()
    print(f"Popped: {popped}, List: {lst}")
    
    popped2 = lst.pop(1)
    print(f"Popped at index: {popped2}, List: {lst}")
    
    lst.clear()
    print(f"Cleared: {lst}")

def test_list_index_count():
    lst = [1, 2, 3, 2, 4, 2, 5]
    idx = lst.index(3)
    print(f"Index of 3: {idx}")
    
    cnt = lst.count(2)
    print(f"Count of 2: {cnt}")

def test_list_sort_reverse():
    lst = [5, 2, 8, 1, 9]
    lst.reverse()
    print(f"Reversed: {lst}")
    
    lst.sort()
    print(f"Sorted: {lst}")
    
    lst.sort(reverse=True)
    print(f"Sorted desc: {lst}")
    
    # Sort with key
    words = ["banana", "pie", "Washington", "book"]
    words.sort(key=len)
    print(f"Sorted by length: {words}")

def test_list_slicing_assignment():
    lst = [1, 2, 3, 4, 5]
    lst[1:3] = [10, 20]
    print(lst)
    
    lst[::2] = [100, 200, 300]
    print(lst)

def test_list_unpacking():
    a, b, c = [1, 2, 3]
    print(f"a={a}, b={b}, c={c}")
    
    # Extended unpacking
    first, *middle, last = [1, 2, 3, 4, 5]
    print(f"First: {first}, Middle: {middle}, Last: {last}")
    
    *start, end = [10, 20, 30, 40]
    print(f"Start: {start}, End: {end}")

def test_list_methods_chain():
    # Methods that return None can't be chained, but we test sequence
    lst = [3, 1, 4, 1, 5, 9, 2, 6]
    lst.append(5)
    lst.sort()
    print(f"Sorted with append: {lst}")

def test():
    test_list_append_extend()
    test_list_insert_remove()
    test_list_pop_clear()
    test_list_index_count()
    test_list_sort_reverse()
    test_list_slicing_assignment()
    test_list_unpacking()
    test_list_methods_chain()

if __name__ == "__main__":
    test()
