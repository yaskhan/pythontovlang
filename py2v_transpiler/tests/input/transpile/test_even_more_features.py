class MathUtils:
    @staticmethod
    def add(a: int, b: int) -> int:
        return a + b
        
    @classmethod
    def create(cls, val: int):
        print(f"Creating from class method: {val}")
        return val

class User:
    def __init__(self, first: str, last: str):
        self._first = first
        self._last = last
        
    @property
    def full_name(self) -> str:
        return f"{self._first} {self._last}"
        
    @full_name.setter
    def full_name(self, value: str):
        parts = value.split(" ")
        if len(parts) == 2:
            self._first = parts[0]
            self._last = parts[1]

def match_status(status: int | str):
    match status:
        case 200:
            print("OK")
        case 404:
            print("Not Found")
        case "error":
            print("Server Error")
        case _:
            print("Unknown")

def test():
    # Test static/class methods
    print(MathUtils.add(1, 2))
    MathUtils.create(10)
    
    # Test property
    u = User("John", "Doe")
    print(u.full_name)
    u.full_name = "Jane Smith"
    print(u.full_name)
    
    # Test match/case
    match_status(200)
    match_status("error")
    match_status(500)

if __name__ == "__main__":
    test()
