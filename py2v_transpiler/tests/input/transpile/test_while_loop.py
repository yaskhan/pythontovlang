def test_while_basic():
    i = 0
    while i < 5:
        print(f"i={i}")
        i += 1

def test_while_with_condition():
    nums = [1, 2, 3, 4, 5]
    i = 0
    while i < len(nums):
        print(f"nums[{i}]={nums[i]}")
        i += 1

def test_while_break():
    i = 0
    while i < 10:
        if i == 5:
            break
        print(f"i={i}")
        i += 1

def test_while_continue():
    i = 0
    while i < 5:
        i += 1
        if i == 3:
            continue
        print(f"i={i}")

def test_while_else():
    i = 0
    while i < 3:
        print(f"i={i}")
        i += 1
    else:
        print("While loop completed normally")

def test_while_else_break():
    i = 0
    while i < 3:
        if i == 2:
            break
        print(f"i={i}")
        i += 1
    else:
        print("This won't print (break)")

def test_while_infinite():
    # Simulated infinite loop with break
    count = 0
    while True:
        if count >= 3:
            break
        print(f"count={count}")
        count += 1

def test_while_nested():
    i = 0
    while i < 3:
        j = 0
        while j < 3:
            print(f"({i}, {j})", end=" ")
            j += 1
        print()
        i += 1

def test_while_decrement():
    i = 5
    while i > 0:
        print(f"i={i}")
        i -= 1

def test_while_multiple_conditions():
    a, b = 0, 10
    while a < 5 and b > 5:
        print(f"a={a}, b={b}")
        a += 1
        b -= 1

def test():
    test_while_basic()
    test_while_with_condition()
    test_while_break()
    test_while_continue()
    test_while_else()
    test_while_else_break()
    test_while_infinite()
    test_while_nested()
    test_while_decrement()
    test_while_multiple_conditions()

if __name__ == "__main__":
    test()
