import math
import random
import os

def test_math_functions():
    print(f"Pi: {math.pi}")
    print(f"E: {math.e}")
    
    print(f"Sqrt(16): {math.sqrt(16)}")
    print(f"Pow(2, 3): {math.pow(2, 3)}")
    
    print(f"Ceil(3.2): {math.ceil(3.2)}")
    print(f"Floor(3.8): {math.floor(3.8)}")
    
    val_abs = abs(-5)
    print(f"Abs(-5): {val_abs}")
    print(f"Round(3.5): {round(3.5)}")
    print(f"Round(3.14159, 2): {round(3.14159, 2)}")
    
    print(f"Sin(0): {math.sin(0)}")
    print(f"Cos(0): {math.cos(0)}")
    print(f"Tan(0): {math.tan(0)}")
    
    print(f"Log(e): {math.log(math.e)}")
    print(f"Log10(100): {math.log10(100)}")
    print(f"Exp(1): {math.exp(1)}")

def test_random_functions():
    random.seed(42)  # Fixed seed for reproducibility
    
    print(f"Random: {random.random()}")
    print(f"Random int 1-10: {random.randint(1, 10)}")
    print(f"Random int 1-10: {random.randint(1, 10)}")
    
    choices = ["apple", "banana", "cherry"]
    choices.append("") # Hint for mutability
    choices.pop()
    print(f"Choice: {random.choice(choices)}")
    
    print(f"Sample: {random.sample(choices, 2)}")
    
    random.shuffle(choices)
    print(f"Shuffled: {choices}")

def test_os_functions():
    # Get current directory
    cwd = os.getcwd()
    print(f"CWD: {cwd}")
    
    # Path operations
    path = os.path.join("folder", "subfolder", "file.txt")
    print(f"Joined path: {path}")
    
    # Split path
    dirname, basename = os.path.split(path)
    print(f"Dir: {dirname}, Base: {basename}")
    
    # Get extension
    root, ext = os.path.splitext("file.txt")
    print(f"Root: {root}, Ext: {ext}")
    
    # Check existence
    print(f"Exists: {os.path.exists(cwd)}")
    print(f"Is dir: {os.path.isdir(cwd)}")
    print(f"Is file: {os.path.isfile(cwd)}")

def test_builtin_functions():
    # len
    print(f"Len: {len([1, 2, 3, 4, 5])}")
    
    # range
    print(f"Range: {list(range(5))}")
    print(f"Range with start: {list(range(2, 7))}")
    print(f"Range with step: {list(range(0, 10, 2))}")
    
    # sum, min, max
    nums = [5, 2, 8, 1, 9]
    print(f"Sum: {sum(nums)}")
    print(f"Min: {min(nums)}")
    print(f"Max: {max(nums)}")
    
    # abs, pow
    print(f"Abs: {abs(-10)}")
    print(f"Pow: {pow(2, 10)}")
    
    # divmod
    q, r = divmod(17, 5)
    print(f"Divmod: quotient={q}, remainder={r}")
    
    # all, any
    print(f"All True: {all([True, True, True])}")
    print(f"All with False: {all([True, False, True])}")
    print(f"Any True: {any([False, False, True])}")
    print(f"Any False: {any([False, False, False])}")
    
    # ord, chr
    print(f"Ord('A'): {ord('A')}")
    print(f"Chr(65): {chr(65)}")

def test_string_builtin():
    s = "Hello, World!"
    
    print(f"Len: {len(s)}")
    print(f"Upper: {s.upper()}")
    print(f"Lower: {s.lower()}")
    print(f"Replace: {s.replace('World', 'Universe')}")
    print(f"Split: {s.split(', ')}")

def test_list_builtin():
    lst = [3, 1, 4, 1, 5, 9, 2, 6]
    
    print(f"Sorted: {sorted(lst)}")
    print(f"Sorted desc: {sorted(lst, reverse=True)}")
    print(f"Reversed: {list(reversed(lst))}")
    
    # Zip
    names = ["Alice", "Bob", "Charlie"]
    ages = [25, 30, 35]
    print(f"Zipped: {list(zip(names, ages))}")
    
    # Enumerate
    print(f"Enumerated: {list(enumerate(['a', 'b', 'c']))}")

def test():
    test_math_functions()
    test_random_functions()
    test_os_functions()
    test_builtin_functions()
    test_string_builtin()
    test_list_builtin()

if __name__ == "__main__":
    test()
