counter = 0

def increment():
    global counter
    counter += 1
    print(f"Counter: {counter}")

class MyContext:
    def __enter__(self):
        print("Entering context")
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        print("Exiting context")

def process():
    with MyContext() as ctx:
        print("Inside context")
        increment()

def remove_item():
    my_dict = {"a": 1, "b": 2}
    del my_dict["a"]
    print(my_dict)
    
    my_list = [10, 20, 30]
    del my_list[1]
    print(my_list)

def test():
    increment()
    process()
    remove_item()

if __name__ == "__main__":
    test()
