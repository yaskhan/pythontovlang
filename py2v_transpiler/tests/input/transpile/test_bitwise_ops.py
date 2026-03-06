def test_bitwise_and():
    a = 12  # 1100 in binary
    b = 10  # 1010 in binary
    result = a & b
    print(f"{a} & {b} = {result}")  # 1000 = 8

def test_bitwise_or():
    a = 12  # 1100
    b = 10  # 1010
    result = a | b
    print(f"{a} | {b} = {result}")  # 1110 = 14

def test_bitwise_xor():
    a = 12  # 1100
    b = 10  # 1010
    result = a ^ b
    print(f"{a} ^ {b} = {result}")  # 0110 = 6

def test_bitwise_not():
    a = 5
    result = ~a
    print(f"~{a} = {result}")  # -6 (two's complement)

def test_bitwise_shift_left():
    a = 4  # 100
    result = a << 2
    print(f"{a} << 2 = {result}")  # 10000 = 16

def test_bitwise_shift_right():
    a = 16  # 10000
    result = a >> 2
    print(f"{a} >> 2 = {result}")  # 100 = 4

def test_bitwise_operations():
    # Check if bit is set
    num = 13  # 1101
    bit_mask = 4  # 0100
    is_set = (num & bit_mask) != 0
    print(f"Bit 2 is set in {num}: {is_set}")
    
    # Set bit
    result = num | 2  # Set bit 1
    print(f"Set bit 1 in {num}: {result}")
    
    # Clear bit
    result = num & ~4  # Clear bit 2
    print(f"Clear bit 2 in {num}: {result}")
    
    # Toggle bit
    result = num ^ 1  # Toggle bit 0
    print(f"Toggle bit 0 in {num}: {result}")

def test_bitwise_flags():
    READ = 1      # 001
    WRITE = 2     # 010
    EXECUTE = 4   # 100
    
    permissions = READ | WRITE  # rw-
    print(f"Permissions: {permissions}")
    
    # Check permission
    has_read = (permissions & READ) != 0
    has_execute = (permissions & EXECUTE) != 0
    print(f"Has read: {has_read}, Has execute: {has_execute}")
    
    # Add execute permission
    permissions |= EXECUTE
    print(f"New permissions: {permissions}")
    
    # Remove write permission
    permissions &= ~WRITE
    print(f"Final permissions: {permissions}")

def test_floor_division():
    a = 17
    b = 5
    result = a // b
    print(f"{a} // {b} = {result}")
    
    # Negative numbers
    result_neg = -17 // 5
    print(f"-17 // 5 = {result_neg}")

def test_modulo():
    a = 17
    b = 5
    result = a % b
    print(f"{a} % {b} = {result}")
    
    # Check if even
    num = 10
    is_even = num % 2 == 0
    print(f"{num} is even: {is_even}")

def test_power():
    base = 2
    exp = 10
    result = base ** exp
    print(f"{base} ** {exp} = {result}")
    
    # Float exponent
    result_sqrt = 16 ** 0.5
    print(f"16 ** 0.5 = {result_sqrt}")

def test_augmented_assignment():
    x = 10
    x += 5
    print(f"x += 5: {x}")
    
    x -= 3
    print(f"x -= 3: {x}")
    
    x *= 2
    print(f"x *= 2: {x}")
    
    x //= 3
    print(f"x //= 3: {x}")
    
    x **= 2
    print(f"x **= 2: {x}")
    
    x %= 7
    print(f"x %= 7: {x}")
    
    x &= 3
    print(f"x &= 3: {x}")
    
    x |= 5
    print(f"x |= 5: {x}")
    
    x ^= 2
    print(f"x ^= 2: {x}")
    
    x >>= 1
    print(f"x >>= 1: {x}")
    
    x <<= 2
    print(f"x <<= 2: {x}")

def test():
    test_bitwise_and()
    test_bitwise_or()
    test_bitwise_xor()
    test_bitwise_not()
    test_bitwise_shift_left()
    test_bitwise_shift_right()
    test_bitwise_operations()
    test_bitwise_flags()
    test_floor_division()
    test_modulo()
    test_power()
    test_augmented_assignment()

if __name__ == "__main__":
    test()
