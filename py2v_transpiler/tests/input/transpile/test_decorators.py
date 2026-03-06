def test_simple_decorator():
    def decorator(func):
        def wrapper():
            print("Before")
            func()
            print("After")
        return wrapper
    
    @decorator
    def say_hello():
        print("Hello!")
    
    say_hello()

def test_decorator_with_args():
    def decorator(func):
        def wrapper(*args, **kwargs):
            print(f"Calling with args: {args}, kwargs: {kwargs}")
            return func(*args, **kwargs)
        return wrapper
    
    @decorator
    def greet(name: str, age: int):
        print(f"Name: {name}, Age: {age}")
    
    greet("Alice", 30)

def test_decorator_return_value():
    def decorator(func):
        def wrapper(*args, **kwargs):
            result = func(*args, **kwargs)
            return result * 2
        return wrapper
    
    @decorator
    def add(a: int, b: int) -> int:
        return a + b
    
    print(add(3, 4))

def test_multiple_decorators():
    def decorator1(func):
        def wrapper(*args, **kwargs):
            print("Decorator 1 before")
            result = func(*args, **kwargs)
            print("Decorator 1 after")
            return result
        return wrapper
    
    def decorator2(func):
        def wrapper(*args, **kwargs):
            print("Decorator 2 before")
            result = func(*args, **kwargs)
            print("Decorator 2 after")
            return result
        return wrapper
    
    @decorator1
    @decorator2
    def test_func():
        print("Inside function")
    
    test_func()

def test_decorator_with_params():
    def repeat(times: int):
        def decorator(func):
            def wrapper(*args, **kwargs):
                for _ in range(times):
                    func(*args, **kwargs)
            return wrapper
        return decorator
    
    @repeat(3)
    def say_hi():
        print("Hi!")
    
    say_hi()

def test_class_decorator():
    class CountCalls:
        def __init__(self, func):
            self.func = func
            self.count = 0
        
        def __call__(self, *args, **kwargs):
            self.count += 1
            print(f"Call {self.count}")
            return self.func(*args, **kwargs)
    
    @CountCalls
    def greet(name: str):
        print(f"Hello, {name}!")
    
    greet("Alice")
    greet("Bob")
    greet("Charlie")

def test_functools_wraps():
    from functools import wraps
    
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            """Wrapper docstring"""
            return func(*args, **kwargs)
        return wrapper
    
    @decorator
    def original_func():
        """Original docstring"""
        pass
    
    print(f"Name: {original_func.__name__}")
    print(f"Doc: {original_func.__doc__}")

def test_property_decorator():
    class Temperature:
        def __init__(self, celsius: float):
            self._celsius = celsius
        
        @property
        def celsius(self) -> float:
            return self._celsius
        
        @celsius.setter
        def celsius(self, value: float):
            if value < -273.15:
                raise ValueError("Below absolute zero")
            self._celsius = value
        
        @property
        def fahrenheit(self) -> float:
            return self._celsius * 9 / 5 + 32
    
    temp = Temperature(25)
    print(f"Celsius: {temp.celsius}")
    print(f"Fahrenheit: {temp.fahrenheit}")
    temp.celsius = 30
    print(f"New Celsius: {temp.celsius}")

def test():
    test_simple_decorator()
    test_decorator_with_args()
    test_decorator_return_value()
    test_multiple_decorators()
    test_decorator_with_params()
    test_class_decorator()
    test_functools_wraps()
    test_property_decorator()

if __name__ == "__main__":
    test()
