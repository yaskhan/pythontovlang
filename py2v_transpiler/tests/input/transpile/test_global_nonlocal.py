def test_global_variable():
    counter = 0
    
    def increment():
        nonlocal counter
        counter += 1
        return counter
    
    print(increment())
    print(increment())
    print(increment())

def test_global_in_multiple_functions():
    total = 100
    
    def add(x: int):
        nonlocal total
        total += x
    
    def subtract(x: int):
        nonlocal total
        total -= x
    
    def get_total():
        return total
    
    add(50)
    print(get_total())
    subtract(30)
    print(get_total())

def test_nested_function():
    def outer(x: int):
        def inner(y: int) -> int:
            return x + y
        return inner
    
    add_5 = outer(5)
    print(add_5(10))
    
    add_10 = outer(10)
    print(add_10(20))

def test_closure_with_state():
    def make_accumulator():
        total = 0
        
        def accumulate(value: int) -> int:
            nonlocal total
            total += value
            return total
        
        return accumulate
    
    acc = make_accumulator()
    print(acc(5))
    print(acc(10))
    print(acc(15))

def test_closure_in_loop():
    funcs = []
    for i in range(5):
        def func(x=i):  # Capture i with default arg
            return x
        funcs.append(func)
    
    for f in funcs:
        print(f())

def test_closure_proper_capture():
    funcs = []
    for i in range(5):
        def func():
            nonlocal_i = i  # This won't work as expected
            return nonlocal_i
        funcs.append(func)
    
    # Note: All functions will return 4 (last value of i)
    # This demonstrates closure behavior
    print("Closure in loop (all return last value):")
    # for f in funcs:
    #     print(f())

def test_multiple_closures():
    def make_counters():
        count_a = 0
        count_b = 0
        
        def increment_a():
            nonlocal count_a
            count_a += 1
            return count_a
        
        def increment_b():
            nonlocal count_b
            count_b += 1
            return count_b
        
        def get_counts():
            return count_a, count_b
        
        return increment_a, increment_b, get_counts
    
    inc_a, inc_b, get = make_counters()
    print(inc_a())
    print(inc_a())
    print(inc_b())
    print(inc_a())
    print(get())

def test_closure_with_list():
    def make_history():
        history = []
        
        def add(item):
            nonlocal history
            history.append(item)
            return history
        
        def get_history():
            return history.copy()
        
        return add, get_history
    
    add, get = make_history()
    add(1)
    add(2)
    add(3)
    print(get())

def test():
    test_global_variable()
    test_global_in_multiple_functions()
    test_nested_function()
    test_closure_with_state()
    test_closure_in_loop()
    test_multiple_closures()
    test_closure_with_list()

if __name__ == "__main__":
    test()
