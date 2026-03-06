def test_slice_basic():
    lst = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    print(f"lst[2:5]: {lst[2:5]}")
    print(f"lst[:4]: {lst[:4]}")
    print(f"lst[6:]: {lst[6:]}")
    print(f"lst[:]: {lst[:]}")

def test_slice_negative():
    lst = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    print(f"lst[-3:]: {lst[-3:]}")
    print(f"lst[:-3]: {lst[:-3]}")
    print(f"lst[-5:-2]: {lst[-5:-2]}")

def test_slice_step():
    lst = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    print(f"lst[::2]: {lst[::2]}")
    print(f"lst[1::2]: {lst[1::2]}")
    print(f"lst[::3]: {lst[::3]}")

def test_slice_reverse():
    lst = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    print(f"lst[::-1]: {lst[::-1]}")
    print(f"lst[::-2]: {lst[::-2]}")
    print(f"lst[7:2:-1]: {lst[7:2:-1]}")

def test_slice_assignment():
    lst = [1, 2, 3, 4, 5]
    lst[1:3] = [10, 20]
    print(f"After lst[1:3] = [10, 20]: {lst}")
    
    lst = [1, 2, 3, 4, 5]
    lst[1:3] = [100]
    print(f"After lst[1:3] = [100]: {lst}")
    
    lst = [1, 2, 3, 4, 5]
    lst[1:3] = [10, 20, 30, 40]
    print(f"After lst[1:3] = [10, 20, 30, 40]: {lst}")

def test_slice_delete():
    lst = [1, 2, 3, 4, 5, 6, 7]
    del lst[2:5]
    print(f"After del lst[2:5]: {lst}")

def test_slice_step_assignment():
    lst = [0, 0, 0, 0, 0]
    lst[::2] = [1, 1, 1]
    print(f"After lst[::2] = [1, 1, 1]: {lst}")

def test_slice_string():
    s = "Hello, World!"
    print(f"s[0:5]: {s[0:5]}")
    print(f"s[::-1]: {s[::-1]}")
    print(f"s[7:-1]: {s[7:-1]}")

def test_slice_tuple():
    t = (0, 1, 2, 3, 4, 5)
    print(f"t[1:4]: {t[1:4]}")
    print(f"t[::-1]: {t[::-1]}")

def test_slice_out_of_bounds():
    lst = [1, 2, 3, 4, 5]
    print(f"lst[0:100]: {lst[0:100]}")  # No error
    print(f"lst[-100:100]: {lst[-100:100]}")  # No error

def test_slice_empty():
    lst = [1, 2, 3]
    print(f"lst[2:1]: {lst[2:1]}")  # Empty
    print(f"lst[5:10]: {lst[5:10]}")  # Empty

def test_slice_copy():
    lst = [1, 2, 3, 4, 5]
    copy = lst[:]
    copy[0] = 100
    print(f"Original: {lst}")
    print(f"Copy: {copy}")

def test():
    test_slice_basic()
    test_slice_negative()
    test_slice_step()
    test_slice_reverse()
    test_slice_assignment()
    test_slice_delete()
    test_slice_step_assignment()
    test_slice_string()
    test_slice_tuple()
    test_slice_out_of_bounds()
    test_slice_empty()
    test_slice_copy()

if __name__ == "__main__":
    test()
