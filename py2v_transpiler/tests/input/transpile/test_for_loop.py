def test_for_basic():
    for i in range(5):
        print(f"i={i}")

def test_for_list():
    for item in [1, 2, 3, 4, 5]:
        print(f"item={item}")

def test_for_string():
    for char in "hello":
        print(f"char={char}")

def test_for_dict():
    d = {"a": 1, "b": 2, "c": 3}
    
    print("Keys:")
    for key in d:
        print(f"key={key}")
    
    print("Values:")
    for value in d.values():
        print(f"value={value}")
    
    print("Items:")
    for key, value in d.items():
        print(f"{key}={value}")

def test_for_break():
    for i in range(10):
        if i == 5:
            break
        print(f"i={i}")

def test_for_continue():
    for i in range(5):
        if i == 2:
            continue
        print(f"i={i}")

def test_for_else():
    for i in range(3):
        print(f"i={i}")
    else:
        print("For loop completed normally")

def test_for_else_break():
    for i in range(3):
        if i == 2:
            break
        print(f"i={i}")
    else:
        print("This won't print (break)")

def test_for_nested():
    for i in range(3):
        for j in range(3):
            print(f"({i}, {j})", end=" ")
        print()

def test_for_enumerate():
    items = ["a", "b", "c", "d"]
    for index, item in enumerate(items):
        print(f"index={index}, item={item}")

def test_for_zip():
    names = ["Alice", "Bob", "Charlie"]
    ages = [25, 30, 35]
    
    for name, age in zip(names, ages):
        print(f"{name} is {age}")

def test_for_unpacking():
    pairs = [(1, 2), (3, 4), (5, 6)]
    for a, b in pairs:
        print(f"a={a}, b={b}")

def test_for_else_found():
    # Pattern: search with else
    target = 5
    for i in range(10):
        if i == target:
            print(f"Found {target}")
            break
    else:
        print(f"{target} not found")

def test():
    test_for_basic()
    test_for_list()
    test_for_string()
    test_for_dict()
    test_for_break()
    test_for_continue()
    test_for_else()
    test_for_else_break()
    test_for_nested()
    test_for_enumerate()
    test_for_zip()
    test_for_unpacking()
    test_for_else_found()

if __name__ == "__main__":
    test()
