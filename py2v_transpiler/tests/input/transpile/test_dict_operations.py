def test_dict_creation():
    # Literal syntax
    d1 = {"a": 1, "b": 2}
    print(d1)
    
    # Using dict constructor
    d2 = dict(a=1, b=2)
    print(d2)
    
    # From pairs
    d3 = dict([("x", 10), ("y", 20)])
    print(d3)

def test_dict_access():
    d = {"name": "Alice", "age": 30, "city": "NYC"}
    print(d["name"])
    print(d.get("age"))
    print(d.get("country", "USA"))  # Default value

def test_dict_modification():
    d = {"a": 1}
    d["b"] = 2  # Add
    d["a"] = 10  # Update
    print(d)

def test_dict_deletion():
    d = {"a": 1, "b": 2, "c": 3}
    val = d.pop("b")
    print(f"Popped: {val}, Dict: {d}")
    
    del d["a"]
    print(f"After del: {d}")
    
    d.clear()
    print(f"Cleared: {d}")

def test_dict_keys_values_items():
    d = {"x": 1, "y": 2, "z": 3}
    
    print("Keys:", list(d.keys()))
    print("Values:", list(d.values()))
    print("Items:", list(d.items()))
    
    # Iteration
    for key in d:
        print(f"Key: {key}")
    
    for key, value in d.items():
        print(f"{key}: {value}")

def test_dict_update():
    d1 = {"a": 1, "b": 2}
    d2 = {"b": 20, "c": 3}
    d1.update(d2)
    print(f"Updated: {d1}")
    
    d1.update(d=4, e=5)
    print(f"Updated with kwargs: {d1}")

def test_dict_comprehension():
    squares = {x: x * x for x in range(5)}
    print(squares)
    
    # Filtered
    even_squares = {x: x * x for x in range(10) if x % 2 == 0}
    print(even_squares)

def test_dict_fromkeys():
    keys = ["a", "b", "c"]
    d = dict.fromkeys(keys, 0)
    print(f"From keys: {d}")
    
    d2 = dict.fromkeys(keys, [])
    print(f"From keys with list: {d2}")

def test_dict_setdefault():
    d = {"a": 1}
    val = d.setdefault("b", 2)
    print(f"Setdefault result: {val}, Dict: {d}")
    
    val2 = d.setdefault("a", 100)  # Key exists
    print(f"Setdefault existing: {val2}, Dict: {d}")

def test_dict_membership():
    d = {"x": 1, "y": 2}
    print("x" in d)
    print("z" not in d)

def test():
    test_dict_creation()
    test_dict_access()
    test_dict_modification()
    test_dict_deletion()
    test_dict_keys_values_items()
    test_dict_update()
    test_dict_comprehension()
    test_dict_fromkeys()
    test_dict_setdefault()
    test_dict_membership()

if __name__ == "__main__":
    test()
