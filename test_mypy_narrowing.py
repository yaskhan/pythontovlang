from typing import Literal, Dict, reveal_type

def test_loop_narrowing() -> None:
    data: Dict[str, int] = {"name": 1, "age": 2}
    for key in ("name", "age"):
        reveal_type(key)

    keys = ("name", "age")
    for k in keys:
         reveal_type(k)
