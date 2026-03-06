def test_function_basic():
    def greet():
        print("Hello!")
    
    greet()

def test_function_with_params():
    def greet(name: str, age: int):
        print(f"Name: {name}, Age: {age}")
    
    greet("Alice", 30)

def test_function_default_params():
    def greet(name: str, greeting: str = "Hello"):
        print(f"{greeting}, {name}!")
    
    greet("Alice")
    greet("Bob", "Hi")

def test_function_keyword_args():
    def describe(name: str, age: int, city: str):
        print(f"{name}, {age}, {city}")
    
    describe(name="Alice", age=30, city="NYC")
    describe(age=25, city="LA", name="Bob")

def test_function_mixed_args():
    def func(a, b, c=10, d=20):
        print(f"a={a}, b={b}, c={c}, d={d}")
    
    func(1, 2)
    func(1, 2, d=30)

def test_function_varargs():
    def sum_all(*args):
        total = 0
        for arg in args:
            total += arg
        return total
    
    print(sum_all(1, 2, 3))
    print(sum_all(1, 2, 3, 4, 5))

def test_function_kwargs():
    def print_kwargs(**kwargs):
        for key, value in kwargs.items():
            print(f"{key}={value}")
    
    print_kwargs(name="Alice", age=30, city="NYC")

def test_function_args_kwargs():
    def func(a, *args, **kwargs):
        print(f"a={a}")
        print(f"args={args}")
        print(f"kwargs={kwargs}")
    
    func(1, 2, 3, 4, name="test", value=42)

def test_function_return():
    def add(a: int, b: int) -> int:
        return a + b
    
    result = add(3, 4)
    print(f"Result: {result}")

def test_function_multiple_returns():
    def min_max(nums):
        return min(nums), max(nums)
    
    result = min_max([3, 1, 4, 1, 5, 9])
    print(f"Min and max: {result}")
    
    min_val, max_val = min_max([3, 1, 4, 1, 5, 9])
    print(f"min={min_val}, max={max_val}")

def test_function_no_return():
    def no_return():
        pass
    
    result = no_return()
    print(f"Result: {result}")  # None

def test_function_nested():
    def outer(x: int):
        def inner(y: int) -> int:
            return x + y
        return inner
    
    add_5 = outer(5)
    print(add_5(10))

def test_function_recursive():
    def factorial(n: int) -> int:
        if n <= 1:
            return 1
        return n * factorial(n - 1)
    
    print(f"5! = {factorial(5)}")

def test_function_recursive_fibonacci():
    def fibonacci(n: int) -> int:
        if n <= 1:
            return n
        return fibonacci(n - 1) + fibonacci(n - 2)
    
    for i in range(10):
        print(f"fib({i})={fibonacci(i)}", end=" ")
    print()

def test():
    test_function_basic()
    test_function_with_params()
    test_function_default_params()
    test_function_keyword_args()
    test_function_mixed_args()
    test_function_varargs()
    test_function_kwargs()
    test_function_args_kwargs()
    test_function_return()
    test_function_multiple_returns()
    test_function_no_return()
    test_function_nested()
    test_function_recursive()
    test_function_recursive_fibonacci()

if __name__ == "__main__":
    test()
