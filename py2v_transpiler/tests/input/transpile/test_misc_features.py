def test_operators():
    # Floor division and power
    a = 10 // 3
    b = 2 ** 3
    print(f"Floor: {a}, Pow: {b}")
    
    # Bitwise operators
    x = 5 ^ 3
    y = 1 << 4
    z = ~x
    print(f"XOR: {x}, LSHIFT: {y}, NOT: {z}")

def test_chained_assignment():
    # Chained assignment
    p = q = r = [1, 2, 3]
    p.append(4)
    print(f"q: {q}, r: {r}")

def test_fstring_formatting():
    val = 3.14159
    # Format specifiers
    print(f"Value formatted: {val:.2f}")
    
    # Nested expression
    print(f"Calculation: {val * 2:.1f}")

def test():
    test_operators()
    test_chained_assignment()
    test_fstring_formatting()

if __name__ == "__main__":
    test()
