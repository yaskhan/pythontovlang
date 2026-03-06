def test_boolean_and():
    a = True
    b = False
    print(f"True and False = {a and b}")
    print(f"True and True = {True and True}")
    print(f"False and anything = {False and 'something'}")

def test_boolean_or():
    a = True
    b = False
    print(f"True or False = {a or b}")
    print(f"False or False = {False or False}")
    print(f"True or anything = {True or 'something'}")

def test_boolean_not():
    print(f"not True = {not True}")
    print(f"not False = {not False}")

def test_boolean_short_circuit_and():
    def should_not_run():
        print("This should not print")
        return True
    
    # Short-circuit: second part not evaluated
    result = False and should_not_run()
    print(f"Result: {result}")

def test_boolean_short_circuit_or():
    def should_not_run():
        print("This should not print")
        return False
    
    # Short-circuit: second part not evaluated
    result = True or should_not_run()
    print(f"Result: {result}")

def test_boolean_chaining():
    x = 5
    result = 0 < x < 10
    print(f"0 < {x} < 10 = {result}")
    
    result = 0 < x < 3
    print(f"0 < {x} < 3 = {result}")

def test_boolean_with_values():
    # Truthy and falsy values
    print(f"bool(0) = {bool(0)}")
    print(f"bool(1) = {bool(1)}")
    print(f"bool('') = {bool('')}")
    print(f"bool('hello') = {bool('hello')}")
    print(f"bool([]) = {bool([])}")
    print(f"bool([1, 2]) = {bool([1, 2])}")
    print(f"bool(None) = {bool(None)}")

def test_boolean_or_default():
    # Using or for default values
    name = ""
    result = name or "Anonymous"
    print(f"Default name: {result}")
    
    name = "Alice"
    result = name or "Anonymous"
    print(f"Actual name: {result}")

def test_boolean_and_conditional():
    # Using and for conditional execution
    enabled = True
    result = enabled and "Feature is enabled"
    print(f"Status: {result}")
    
    enabled = False
    result = enabled and "Feature is enabled"
    print(f"Status: {result}")

def test_boolean_comparison():
    a = 10
    b = 20
    
    print(f"a == b: {a == b}")
    print(f"a != b: {a != b}")
    print(f"a < b: {a < b}")
    print(f"a > b: {a > b}")
    print(f"a <= b: {a <= b}")
    print(f"a >= b: {a >= b}")

def test_boolean_identity():
    a = [1, 2, 3]
    b = [1, 2, 3]
    c = a
    
    print(f"a == b: {a == b}")  # Same values
    print(f"a is b: {a is b}")  # Different objects
    print(f"a is c: {a is c}")  # Same object
    
    print(f"a is not b: {a is not b}")
    print(f"a is not c: {a is not c}")

def test_boolean_in():
    lst = [1, 2, 3, 4, 5]
    print(f"3 in list: {3 in lst}")
    print(f"10 in list: {10 in lst}")
    print(f"10 not in list: {10 not in lst}")

def test():
    test_boolean_and()
    test_boolean_or()
    test_boolean_not()
    test_boolean_short_circuit_and()
    test_boolean_short_circuit_or()
    test_boolean_chaining()
    test_boolean_with_values()
    test_boolean_or_default()
    test_boolean_and_conditional()
    test_boolean_comparison()
    test_boolean_identity()
    test_boolean_in()

if __name__ == "__main__":
    test()
