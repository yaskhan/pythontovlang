def test_basic_string_methods():
    s = "  Hello, World!  "
    print(s.strip())
    print(s.lstrip())
    print(s.rstrip())
    
    print(s.lower())
    print(s.upper())
    print(s.capitalize())
    print(s.title())

def test_string_split_join():
    text = "apple,banana,cherry"
    parts = text.split(",")
    print(parts)
    
    joined = "-".join(parts)
    print(joined)
    
    # Split with maxsplit
    limited = text.split(",", 1)
    print(limited)

def test_string_replace():
    s = "hello world"
    replaced = s.replace("world", "universe")
    print(replaced)
    
    # Replace with count
    s2 = "aaaabaaa"
    replaced2 = s2.replace("a", "x", 3)
    print(replaced2)

def test_string_find_index():
    s = "hello world"
    print(s.find("world"))
    print(s.find("python"))  # Returns -1
    print(s.index("world"))
    # s.index("python")  # Would raise ValueError
    
    print(s.startswith("hello"))
    print(s.endswith("world"))

def test_string_format():
    name = "Alice"
    age = 30
    
    # Using format method
    msg = "My name is {} and I am {}".format(name, age)
    print(msg)
    
    # Using named placeholders
    msg2 = "My name is {name} and I am {age}".format(name="Bob", age=25)
    print(msg2)
    
    # Using format specifiers
    pi = 3.14159265359
    print("Pi: {:.2f}".format(pi))
    print("Number: {:05d}".format(42))

def test_string_slicing():
    s = "Programming"
    print(s[0:4])
    print(s[4:])
    print(s[:4])
    print(s[-3:])
    print(s[::2])
    print(s[::-1])  # Reverse

def test_string_checks():
    s1 = "hello123"
    s2 = "HELLO"
    s3 = "hello"
    s4 = "123"
    s5 = "Hello World"
    
    print(s1.isalnum())
    print(s2.isupper())
    print(s3.islower())
    print(s4.isdigit())
    print(s5.istitle())
    print(s5.isalpha())

def test():
    test_basic_string_methods()
    test_string_split_join()
    test_string_replace()
    test_string_find_index()
    test_string_format()
    test_string_slicing()
    test_string_checks()

if __name__ == "__main__":
    test()
