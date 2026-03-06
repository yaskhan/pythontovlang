from typing import Optional, Any, Union, List, Dict, Tuple

def basic_types(x: int, y: float, name: str, active: bool) -> int:
    result: int = x + int(y)
    print(f"Name: {name}, Active: {active}")
    return result

def optional_type(value: Optional[int]) -> str:
    if value is None:
        return "No value"
    return f"Value is {value}"

def union_type(x: Union[int, str]) -> str:
    if isinstance(x, int):
        return f"Number: {x}"
    return f"String: {x}"

def any_type(data: Any) -> Any:
    return data

def list_operations(nums: List[int]) -> List[int]:
    result: List[int] = []
    for n in nums:
        result.append(n * 2)
    return result

def dict_operations(data: Dict[str, int]) -> Dict[str, int]:
    result: Dict[str, int] = {}
    for key, value in data.items():
        result[key] = value * 2
    return result

def tuple_unpack(coords: Tuple[int, int]) -> int:
    x, y = coords
    return x + y

def nested_types(matrix: List[List[int]]) -> List[int]:
    flat: List[int] = []
    for row in matrix:
        for val in row:
            flat.append(val)
    return flat

def complex_dict(data: Dict[str, List[int]]) -> List[int]:
    result: List[int] = []
    for key, values in data.items():
        result.extend(values)
    return result

def return_none(x: int) -> None:
    if x > 0:
        print(f"Positive: {x}")
    else:
        print(f"Non-positive: {x}")

def function_type(f: callable, x: int) -> int:
    return f(x)

def apply_function(f: callable, values: List[int]) -> List[int]:
    result: List[int] = []
    for v in values:
        result.append(f(v))
    return result

def run_test():
    print(basic_types(5, 3.14, "Alice", True))
    print(optional_type(None))
    print(optional_type(42))
    print(union_type(10))
    print(union_type("hello"))
    print(any_type(123))
    print(any_type("anything"))
    print(list_operations([1, 2, 3, 4]))
    print(dict_operations({"a": 1, "b": 2}))
    print(tuple_unpack((3, 4)))
    print(nested_types([[1, 2], [3, 4], [5, 6]]))
    print(complex_dict({"nums1": [1, 2], "nums2": [3, 4]}))
    return_none(10)
    return_none(-5)
    
    def square(x: int) -> int:
        return x * x
    
    print(apply_function(square, [1, 2, 3, 4, 5]))

if __name__ == "__main__":
    run_test()
