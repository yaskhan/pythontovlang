def test_none_check():
    value = None
    print(f"value is None: {value is None}")
    print(f"value is not None: {value is not None}")
    
    value = 42
    print(f"42 is None: {value is None}")

def test_none_default():
    def greet(name=None):
        if name is None:
            return "Hello, guest!"
        return f"Hello, {name}!"
    
    print(greet())
    print(greet("Alice"))

def test_none_in_list():
    lst = [1, None, 3, None, 5]
    print(f"None count: {lst.count(None)}")
    print(f"None in list: {None in lst}")

def test_none_return():
    def no_return():
        pass
    
    result = no_return()
    print(f"No return result: {result}")
    print(f"Is None: {result is None}")

def test_none_assignment():
    x = None
    y = 10
    
    print(f"x = {x}")
    x = y
    print(f"After x = y, x = {x}")
    y = None
    print(f"After y = None, y = {y}, x = {x}")

def test_none_in_dict():
    d = {"a": 1, "b": None, "c": 3}
    print(f"Dict with None value: {d}")
    print(f"d['b'] is None: {d['b'] is None}")
    
    # Get with None default
    print(f"d.get('d'): {d.get('d')}")
    print(f"d.get('d') is None: {d.get('d') is None}")

def test_none_filter():
    data = [1, None, 2, None, 3]
    filtered = [x for x in data if x is not None]
    print(f"Filtered: {filtered}")

def test_none_or():
    # None or value
    value = None
    result = value or "default"
    print(f"None or 'default': {result}")
    
    value = "actual"
    result = value or "default"
    print(f"'actual' or 'default': {result}")

def test_none_ternary():
    def get_value(x=None):
        return "No value" if x is None else f"Value: {x}"
    
    print(get_value())
    print(get_value(42))

def test_none_comparison():
    # None comparisons
    print(f"None == None: {None == None}")
    print(f"None is None: {None is None}")
    
    # Note: Comparisons like None < 1 raise TypeError in Python 3
    # print(f"None < 1: {None < 1}")  # Would raise TypeError

def test():
    test_none_check()
    test_none_default()
    test_none_in_list()
    test_none_return()
    test_none_assignment()
    test_none_in_dict()
    test_none_filter()
    test_none_or()
    test_none_ternary()
    test_none_comparison()

if __name__ == "__main__":
    test()
