def test_list_comprehension():
    # Simple list comprehension
    squares = [x * x for x in range(10)]
    print(squares)

    # With condition
    evens = [x for x in range(20) if x % 2 == 0]
    print(evens)

    # Nested comprehension
    matrix = [[i * j for j in range(3)] for i in range(3)]
    print(matrix)

def test_dict_comprehension():
    # Simple dict comprehension
    square_map = {x: x * x for x in range(5)}
    print(square_map)

    # With condition
    even_map = {x: x * 2 for x in range(10) if x % 2 == 0}
    print(even_map)

def test_set_comprehension():
    # Set comprehension
    unique_squares = {x * x for x in range(-3, 4)}
    print(unique_squares)

def test_generator_expression():
    # Generator expression
    gen = (x * x for x in range(5))
    for val in gen:
        print(val)

    # With condition
    filtered_gen = (x for x in range(10) if x > 5)
    for val in filtered_gen:
        print(val)

def test_nested_loops_in_comprehension():
    # Multiple for clauses
    pairs = [(x, y) for x in range(3) for y in range(3)]
    print(pairs)

    # With condition on both
    filtered_pairs = [(x, y) for x in range(5) for y in range(5) if x + y < 5]
    print(filtered_pairs)

def test():
    test_list_comprehension()
    test_dict_comprehension()
    test_set_comprehension()
    test_generator_expression()
    test_nested_loops_in_comprehension()

if __name__ == "__main__":
    test()
