from typing import Optional, Any, Union, List, Dict, Tuple

def test_basic_types(x: int, y: float, name: str, active: bool) -> int:
    result: int = x + int(y)
    print(f"Name: {name}, Active: {active}")
    return result

def test_optional(value: Optional[int]) -> str:
    if value is None:
        return "No value"
    return f"Value is {value}"

def test_union(x: Union[int, str]) -> str:
    if isinstance(x, int):
        return f"Number: {x}"
    return f"String: {x}"

def test_any(data: Any) -> Any:
    return data

def test_list_operations(nums: List[int]) -> List[int]:
    result: List[int] = []
    for n in nums:
        result.append(n * 2)
    return result

def test_dict_operations(data: Dict[str, int]) -> Dict[str, int]:
    result: Dict[str, int] = {}
    for key, value in data.items():
        result[key] = value * 2
    return result

def test_tuple_unpack(coords: Tuple[int, int]) -> int:
    x, y = coords
    return x + y

def test_nested_types(matrix: List[List[int]]) -> List[int]:
    flat: List[int] = []
    for row in matrix:
        for val in row:
            flat.append(val)
    return flat

def test_complex_dict(data: Dict[str, List[int]]) -> List[int]:
    result: List[int] = []
    for key, values in data.items():
        result.extend(values)
    return result

def test_return_none(x: int) -> None:
    if x > 0:
        print(f"Positive: {x}")
    else:
        print(f"Non-positive: {x}")

def test_function_type(f: callable, x: int) -> int:
    return f(x)

def apply_function(f: callable, values: List[int]) -> List[int]:
    result: List[int] = []
    for v in values:
        result.append(f(v))
    return result

def test():
    print(test_basic_types(5, 3.14, "Alice", True))
    print(test_optional(None))
    print(test_optional(42))
    print(test_union(10))
    print(test_union("hello"))
    print(test_any(123))
    print(test_any("anything"))
    print(test_list_operations([1, 2, 3, 4]))
    print(test_dict_operations({"a": 1, "b": 2}))
    print(test_tuple_unpack((3, 4)))
    print(test_nested_types([[1, 2], [3, 4], [5, 6]]))
    print(test_complex_dict({"nums1": [1, 2], "nums2": [3, 4]}))
    test_return_none(10)
    test_return_none(-5)
    
    def square(x: int) -> int:
        return x * x
    
    print(apply_function(square, [1, 2, 3, 4, 5]))

if __name__ == "__main__":
    test()
