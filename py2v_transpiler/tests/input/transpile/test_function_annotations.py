def test_function_annotations():
    def greet(name: str, age: int) -> str:
        return f"{name} is {age} years old"
    
    print(greet("Alice", 30))

def test_function_annotations_types():
    def process(
        nums: list[int],
        data: dict[str, int],
        point: tuple[int, int]
    ) -> list[int]:
        return nums
    
    print(process([1, 2, 3], {"a": 1}, (0, 0)))

def test_function_annotations_optional():
    from typing import Optional
    
    def greet(name: Optional[str]) -> str:
        if name is None:
            return "Hello, guest!"
        return f"Hello, {name}!"
    
    print(greet(None))
    print(greet("Alice"))

def test_function_annotations_union():
    from typing import Union
    
    def process(value: Union[int, str]) -> str:
        if isinstance(value, int):
            return f"Number: {value}"
        return f"String: {value}"
    
    print(process(42))
    print(process("hello"))

def test_function_annotations_any():
    from typing import Any
    
    def identity(x: Any) -> Any:
        return x
    
    print(identity(42))
    print(identity("hello"))
    print(identity([1, 2, 3]))

def test_function_annotations_callable():
    from typing import Callable
    
    def apply(func: Callable[[int], int], value: int) -> int:
        return func(value)
    
    def double(x: int) -> int:
        return x * 2
    
    print(apply(double, 10))

def test_function_annotations_list():
    from typing import List
    
    def process(nums: List[int]) -> List[int]:
        return [x * 2 for x in nums]
    
    print(process([1, 2, 3, 4, 5]))

def test_function_annotations_dict():
    from typing import Dict
    
    def process(data: Dict[str, int]) -> Dict[str, int]:
        return {k: v * 2 for k, v in data.items()}
    
    print(process({"a": 1, "b": 2}))

def test_function_annotations_tuple():
    from typing import Tuple
    
    def process(point: Tuple[int, int]) -> int:
        x, y = point
        return x + y
    
    print(process((3, 4)))

def test_function_annotations_nested():
    from typing import List, Dict
    
    def process(data: Dict[str, List[int]]) -> List[int]:
        result = []
        for values in data.values():
            result.extend(values)
        return result
    
    print(process({"a": [1, 2], "b": [3, 4]}))

def test_function_annotations_default():
    def greet(name: str = "Guest") -> str:
        return f"Hello, {name}!"
    
    print(greet())
    print(greet("Alice"))

def test_function_annotations_mixed():
    from typing import Optional, List
    
    def process(
        name: str,
        nums: Optional[List[int]] = None,
        multiplier: int = 1
    ) -> List[int]:
        if nums is None:
            nums = []
        return [x * multiplier for x in nums]
    
    print(process("test"))
    print(process("test", [1, 2, 3], 2))

def test():
    test_function_annotations()
    test_function_annotations_types()
    test_function_annotations_optional()
    test_function_annotations_union()
    test_function_annotations_any()
    test_function_annotations_callable()
    test_function_annotations_list()
    test_function_annotations_dict()
    test_function_annotations_tuple()
    test_function_annotations_nested()
    test_function_annotations_default()
    test_function_annotations_mixed()

if __name__ == "__main__":
    test()
