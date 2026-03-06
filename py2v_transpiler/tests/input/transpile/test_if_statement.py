def test_if_basic():
    x = 10
    if x > 5:
        print(f"{x} > 5")

def test_if_else():
    x = 3
    if x > 5:
        print(f"{x} > 5")
    else:
        print(f"{x} <= 5")

def test_if_elif_else():
    x = 5
    if x > 10:
        print(f"{x} > 10")
    elif x > 5:
        print(f"{x} > 5")
    elif x == 5:
        print(f"{x} == 5")
    else:
        print(f"{x} < 5")

def test_if_nested():
    x = 10
    y = 20
    if x > 5:
        if y > 15:
            print(f"x > 5 and y > 15")

def test_if_and_condition():
    x = 10
    y = 20
    if x > 5 and y > 15:
        print(f"Both conditions true")

def test_if_or_condition():
    x = 3
    y = 10
    if x > 5 or y > 5:
        print(f"At least one condition true")

def test_if_not():
    x = False
    if not x:
        print("x is False")

def test_if_in():
    lst = [1, 2, 3, 4, 5]
    if 3 in lst:
        print("3 is in the list")

def test_if_is():
    x = None
    if x is None:
        print("x is None")

def test_if_ternary():
    x = 10
    result = "positive" if x > 0 else "non-positive"
    print(f"x is {result}")

def test_if_multiple_elif():
    score = 85
    if score >= 90:
        grade = "A"
    elif score >= 80:
        grade = "B"
    elif score >= 70:
        grade = "C"
    elif score >= 60:
        grade = "D"
    else:
        grade = "F"
    print(f"Grade: {grade}")

def test_if_truthy():
    value = "hello"
    if value:
        print(f"Truthy value: {value}")
    
    empty = ""
    if not empty:
        print("Empty string is falsy")

def test_if_comparison_chain():
    x = 5
    if 0 < x < 10:
        print(f"{x} is between 0 and 10")

def test():
    test_if_basic()
    test_if_else()
    test_if_elif_else()
    test_if_nested()
    test_if_and_condition()
    test_if_or_condition()
    test_if_not()
    test_if_in()
    test_if_is()
    test_if_ternary()
    test_if_multiple_elif()
    test_if_truthy()
    test_if_comparison_chain()

if __name__ == "__main__":
    test()
