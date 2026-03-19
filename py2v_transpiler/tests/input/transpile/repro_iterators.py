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
