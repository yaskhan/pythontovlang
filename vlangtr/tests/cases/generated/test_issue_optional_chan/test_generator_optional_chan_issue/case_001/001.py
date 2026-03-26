def my_counter(n: int):
    for i in range(n):
        yield i

def test():
    for num in my_counter(3):
        print(num)
