from typing import TypeGuard, List

def is_str_list(val: List[object]) -> TypeGuard[List[str]]:
    return True
