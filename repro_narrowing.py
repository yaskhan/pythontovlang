from typing import Literal, Dict

def test_loop_narrowing() -> None:
    data: Dict[str, int] = {"name": 1, "age": 2}
    for key in ("name", "age"):
        # print is a builtin, but we can call a method on a class to trigger get_method_hook
        # or an attribute access to trigger get_attribute_hook
        _ = key.upper()
        _ = data[key]
