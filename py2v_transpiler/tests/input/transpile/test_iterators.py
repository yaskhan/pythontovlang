def test_iter_next():
    lst = [10, 20, 30, 40]
    it = iter(lst)
    
    print(next(it))
    print(next(it))
    print(next(it))
    print(next(it))
    
    # With default
    print(next(it, "Exhausted"))

def test_custom_iterator():
    class Counter:
        def __init__(self, start: int, end: int):
            self.current = start
            self.end = end
        
        def __iter__(self):
            return self
        
        def __next__(self) -> int:
            if self.current >= self.end:
                raise StopIteration
            result = self.current
            self.current += 1
            return result
    
    counter = Counter(0, 5)
    for num in counter:
        print(num)

def test_iterator_consumption():
    data = [1, 2, 3, 4, 5]
    it = iter(data)
    
    # Consume with list
    remaining = list(it)
    print(f"Remaining: {remaining}")

def test_zip_iterator():
    names = ["Alice", "Bob", "Charlie"]
    ages = [25, 30, 35]
    
    for name, age in zip(names, ages):
        print(f"{name} is {age} years old")
    
    # With different lengths
    scores = [100, 90]
    for name, age, score in zip(names, ages, scores):
        print(f"{name}: {age} years, {score} points")

def test_enumerate_iterator():
    items = ["apple", "banana", "cherry"]
    
    for index, item in enumerate(items):
        print(f"{index}: {item}")
    
    # With start index
    for index, item in enumerate(items, start=1):
        print(f"{index}: {item}")

def test_reversed_iterator():
    data = [1, 2, 3, 4, 5]
    
    for item in reversed(data):
        print(item)
    
    # String
    text = "hello"
    for char in reversed(text):
        print(char, end="")
    print()

def test_sorted_iterator():
    data = [3, 1, 4, 1, 5, 9, 2, 6]
    
    for item in sorted(data):
        print(item, end=" ")
    print()
    
    # With reverse
    for item in sorted(data, reverse=True):
        print(item, end=" ")
    print()
    
    # With key
    words = ["banana", "pie", "Washington", "book"]
    for word in sorted(words, key=len):
        print(word, end=" ")
    print()

def test_filter_iterator():
    nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    for n in filter(lambda x: x % 2 == 0, nums):
        print(n, end=" ")
    print()

def test_map_iterator():
    nums = [1, 2, 3, 4, 5]
    
    for n in map(lambda x: x * x, nums):
        print(n, end=" ")
    print()

def test():
    test_iter_next()
    test_custom_iterator()
    test_iterator_consumption()
    test_zip_iterator()
    test_enumerate_iterator()
    test_reversed_iterator()
    test_sorted_iterator()
    test_filter_iterator()
    test_map_iterator()

if __name__ == "__main__":
    test()
