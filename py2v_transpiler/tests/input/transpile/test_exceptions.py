def test_basic_try_except():
    try:
        result = 10 / 2
        print(f"Result: {result}")
    except ZeroDivisionError:
        print("Division by zero!")

def test_multiple_except():
    try:
        value = int("not a number")
    except ValueError:
        print("ValueError caught")
    except TypeError:
        print("TypeError caught")

def test_except_with_as():
    try:
        result = 10 / 0
    except ZeroDivisionError as e:
        print(f"Caught exception: {e}")

def test_else_clause():
    try:
        result = 10 / 2
    except ZeroDivisionError:
        print("Division by zero")
    else:
        print(f"Division successful: {result}")

def test_finally_clause():
    try:
        print("Trying...")
        result = 10 / 2
    except ZeroDivisionError:
        print("Error")
    finally:
        print("Finally block always executes")

def test_raise_exception():
    try:
        raise ValueError("Custom error message")
    except ValueError as e:
        print(f"Caught: {e}")

def test_raise_with_cause():
    try:
        try:
            int("invalid")
        except ValueError as e:
            raise TypeError("Conversion failed") from e
    except TypeError as e:
        print(f"Caught with cause: {e}")
        print(f"__cause__: {e.__cause__}")

def test_assert_statement():
    x = 5
    try:
        assert x == 5, "x should be 5"
        print("Assertion passed")
    except AssertionError as e:
        print(f"Assertion failed: {e}")

def test_nested_exceptions():
    try:
        try:
            raise ValueError("Inner error")
        except ValueError:
            raise RuntimeError("Outer error")
    except RuntimeError as e:
        print(f"Caught outer: {e}")

def test_exception_in_function():
    def divide(a, b):
        if b == 0:
            raise ZeroDivisionError("Cannot divide by zero")
        return a / b
    
    try:
        result = divide(10, 0)
    except ZeroDivisionError as e:
        print(f"Function exception: {e}")

def test():
    test_basic_try_except()
    test_multiple_except()
    test_except_with_as()
    test_else_clause()
    test_finally_clause()
    test_raise_exception()
    test_raise_with_cause()
    test_assert_statement()
    test_nested_exceptions()
    test_exception_in_function()

if __name__ == "__main__":
    test()
