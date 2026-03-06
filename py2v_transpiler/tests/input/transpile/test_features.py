from typing import Callable

# 1. Lambdas
def get_sorter() -> Callable[[int], int]:
    return lambda x: x * -1

# 2. Generators
def my_counter(n: int):
    for i in range(n):
        yield i

# 3. Multiple Inheritance
class LoggerMixin:
    def log(self, message: str):
        print(f"Log: {message}")

class DatabaseHandler:
    def save(self, data: str):
        print(f"Saving {data} to DB")

class ApplicationService(LoggerMixin, DatabaseHandler):
    def process(self):
        self.log("Starting process")
        self.save("user_data")
        self.log("Process complete")

def test():
    # Test lambda
    sorter = get_sorter()
    print(sorter(5))
    
    # Test generator
    for num in my_counter(3):
        print(num)
        
    # Test multiple inheritance
    app = ApplicationService()
    app.process()

if __name__ == "__main__":
    test()
