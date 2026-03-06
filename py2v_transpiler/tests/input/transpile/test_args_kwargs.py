def test_function_args():
    def print_args(*args):
        for arg in args:
            print(f"arg={arg}")
    
    print_args(1, 2, 3)
    print_args("a", "b", "c")

def test_function_kwargs():
    def print_kwargs(**kwargs):
        for key, value in kwargs.items():
            print(f"{key}={value}")
    
    print_kwargs(a=1, b=2, c=3)
    print_kwargs(name="Alice", age=30)

def test_function_args_kwargs():
    def func(*args, **kwargs):
        print(f"args={args}")
        print(f"kwargs={kwargs}")
    
    func(1, 2, 3, name="test", value=42)

def test_function_positional_only():
    def func(a, b, /, c, d):
        print(f"a={a}, b={b}, c={c}, d={d}")
    
    func(1, 2, c=3, d=4)
    func(1, 2, 3, 4)

def test_function_keyword_only():
    def func(a, *, b, c):
        print(f"a={a}, b={b}, c={c}")
    
    func(1, b=2, c=3)

def test_function_mixed_params():
    def func(a, b, /, c, d, *, e, f):
        print(f"a={a}, b={b}, c={c}, d={d}, e={e}, f={f}")
    
    func(1, 2, 3, d=4, e=5, f=6)

def test_args_unpacking():
    def func(a, b, c):
        print(f"a={a}, b={b}, c={c}")
    
    args = [1, 2, 3]
    func(*args)

def test_kwargs_unpacking():
    def func(a, b, c):
        print(f"a={a}, b={b}, c={c}")
    
    kwargs = {"a": 1, "b": 2, "c": 3}
    func(**kwargs)

def test_args_kwargs_unpacking():
    def func(a, b, c, d, e):
        print(f"a={a}, b={b}, c={c}, d={d}, e={e}")
    
    args = [1, 2]
    kwargs = {"c": 3, "d": 4, "e": 5}
    func(*args, **kwargs)

def test_args_tuple():
    def func(*args):
        print(f"args type: {type(args)}")
        print(f"args[0]: {args[0]}")
        print(f"args[-1]: {args[-1]}")
        for arg in args:
            print(f"  {arg}")
    
    func(1, 2, 3, 4, 5)

def test_kwargs_dict():
    def func(**kwargs):
        print(f"kwargs type: {type(kwargs)}")
        print(f"kwargs keys: {list(kwargs.keys())}")
        for key, value in kwargs.items():
            print(f"  {key}={value}")
    
    func(a=1, b=2, c=3)

def test_args_default_with_args():
    def func(a, b=10, *args):
        print(f"a={a}, b={b}, args={args}")
    
    func(1)
    func(1, 2)
    func(1, 2, 3, 4, 5)

def test_args_default_with_kwargs():
    def func(a, b=10, **kwargs):
        print(f"a={a}, b={b}, kwargs={kwargs}")
    
    func(1)
    func(1, 2)
    func(1, 2, c=3, d=4)

def test():
    test_function_args()
    test_function_kwargs()
    test_function_args_kwargs()
    test_function_positional_only()
    test_function_keyword_only()
    test_function_mixed_params()
    test_args_unpacking()
    test_kwargs_unpacking()
    test_args_kwargs_unpacking()
    test_args_tuple()
    test_kwargs_dict()
    test_args_default_with_args()
    test_args_default_with_kwargs()

if __name__ == "__main__":
    test()
