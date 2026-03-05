class Data:
    value: int | str = 0
    def __init__(self):
        pass

def test():
    d = Data()
    d.value = "hello"
    print(d.value.upper())

    d.value = 123
    print(d.value + 1)

if __name__ == "__main__":
    test()
