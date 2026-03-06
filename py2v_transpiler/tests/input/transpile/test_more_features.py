import asyncio

# 1. Decorator
def my_decorator(func):
    def wrapper(*args, **kwargs):
        print("Before call")
        result = func(*args, **kwargs)
        print("After call")
        return result
    return wrapper

@my_decorator
def greet(name: str):
    print(f"Hello, {name}!")
    return name

# 2. Async/Await
async def fetch_data(id: int) -> str:
    print(f"Fetching {id}...")
    await asyncio.sleep(0.1)
    return f"Data_{id}"

async def main_async():
    data = await fetch_data(42)
    print(data)

def test():
    # Test decorator and kwargs
    greet("Alice")
    
    # Test async
    asyncio.run(main_async())

if __name__ == "__main__":
    test()
