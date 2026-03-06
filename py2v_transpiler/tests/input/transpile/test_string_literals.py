def test_raw_string():
    path = r"C:\Users\Name\Documents"
    print(f"Raw path: {path}")
    
    regex = r"\d+\.\d+"
    print(f"Regex: {regex}")

def test_unicode_string():
    greeting = "Привет"
    emoji = "😀"
    print(f"Unicode: {greeting}, Emoji: {emoji}")

def test_byte_string():
    b = b"hello"
    print(f"Bytes: {b}")
    print(f"Bytes decoded: {b.decode('utf-8')}")

def test_triple_quoted_string():
    multiline = """Line 1
Line 2
Line 3"""
    print(multiline)

def test_string_concat():
    a = "Hello"
    b = "World"
    result = a + " " + b
    print(f"Concat: {result}")

def test_string_repeat():
    result = "Ha" * 3
    print(f"Repeat: {result}")

def test_string_compare():
    a = "apple"
    b = "banana"
    print(f"'{a}' < '{b}': {a < b}")
    print(f"'{a}' == '{a}': {a == a}")

def test_string_interpolation_fstring():
    name = "Alice"
    age = 30
    height = 1.75
    
    print(f"Name: {name}")
    print(f"Age: {age}")
    print(f"Height: {height:.2f}")
    print(f"Next year: {age + 1}")

def test_string_escaping():
    s = "He said, \"Hello!\""
    print(s)
    
    newline = "Line1\nLine2"
    print(newline)
    
    tab = "Col1\tCol2"
    print(tab)
    
    backslash = "C:\\path\\to\\file"
    print(backslash)

def test_string_partition():
    s = "user@example.com"
    before, sep, after = s.partition("@")
    print(f"Before: {before}, Sep: {sep}, After: {after}")

def test_string_rpartition():
    s = "path/to/file.txt"
    before, sep, after = s.rpartition("/")
    print(f"Before: {before}, Sep: {sep}, After: {after}")

def test_string_expandtabs():
    s = "Col1\tCol2\tCol3"
    expanded = s.expandtabs(8)
    print(expanded)

def test_string_encode():
    s = "Hello"
    encoded = s.encode("utf-8")
    print(f"Encoded: {encoded}")

def test_string_format_map():
    data = {"name": "Bob", "age": 25}
    result = "{name} is {age} years old".format_map(data)
    print(result)

def test_string_maketrans():
    table = str.maketrans("aeiou", "12345")
    s = "hello"
    translated = s.translate(table)
    print(f"Translated: {translated}")

def test():
    test_raw_string()
    test_unicode_string()
    test_byte_string()
    test_triple_quoted_string()
    test_string_concat()
    test_string_repeat()
    test_string_compare()
    test_string_interpolation_fstring()
    test_string_escaping()
    test_string_partition()
    test_string_rpartition()
    test_string_expandtabs()
    test_string_encode()
    test_string_format_map()
    test_string_maketrans()

if __name__ == "__main__":
    test()
