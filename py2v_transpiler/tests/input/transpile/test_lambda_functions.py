def test_lambda_basic():
    add = lambda x, y: x + y
    print(add(5, 3))
    
    multiply = lambda x, y: x * y
    print(multiply(4, 7))

def test_lambda_with_default():
    power = lambda x, n=2: x ** n
    print(power(5))
    print(power(5, 3))

def test_lambda_in_sort():
    pairs = [(1, 3), (4, 1), (2, 2), (3, 0)]
    sorted_pairs = sorted(pairs, key=lambda x: x[1])
    print(sorted_pairs)
    
    # Sort by second element descending
    sorted_desc = sorted(pairs, key=lambda x: -x[1])
    print(sorted_desc)

def test_lambda_filter_map():
    nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    # Filter even
    evens = list(filter(lambda x: x % 2 == 0, nums))
    print(evens)
    
    # Map to squares
    squares = list(map(lambda x: x * x, nums))
    print(squares)

def test_lambda_reduce():
    from functools import reduce
    
    nums = [1, 2, 3, 4, 5]
    total = reduce(lambda x, y: x + y, nums)
    print(f"Sum: {total}")
    
    product = reduce(lambda x, y: x * y, nums)
    print(f"Product: {product}")
    
    max_val = reduce(lambda x, y: x if x > y else y, nums)
    print(f"Max: {max_val}")

def test_lambda_composition():
    f = lambda x: x + 1
    g = lambda x: x * 2
    
    # Compose
    composed = lambda x: g(f(x))
    print(composed(5))  # (5 + 1) * 2 = 12

def test_lambda_in_list_comprehension():
    nums = [1, 2, 3, 4, 5]
    funcs = [lambda x, i=i: x + i for i in range(5)]
    
    for f in funcs:
        print(f(10))

def test_lambda_with_args():
    # *args
    sum_all = lambda *args: sum(args)
    print(sum_all(1, 2, 3, 4, 5))
    
    # **kwargs
    print_kwargs = lambda **kwargs: list(kwargs.keys())
    print(print_kwargs(a=1, b=2, c=3))

def test_nested_lambda():
    # Lambda returning lambda
    multiplier = lambda n: lambda x: x * n
    
    times_2 = multiplier(2)
    times_3 = multiplier(3)
    
    print(times_2(5))
    print(times_3(5))

def test():
    test_lambda_basic()
    test_lambda_with_default()
    test_lambda_in_sort()
    test_lambda_filter_map()
    test_lambda_reduce()
    test_lambda_composition()
    test_lambda_in_list_comprehension()
    test_lambda_with_args()
    test_nested_lambda()

if __name__ == "__main__":
    test()
