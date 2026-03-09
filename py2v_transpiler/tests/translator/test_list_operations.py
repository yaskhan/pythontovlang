import pytest
from .utils import transpile_and_verify

def test_list_literals():
    code = """
def process(arr: list[int]) -> None:
    print(arr)

# Test 1: Simple list literal
x = [1, 2, 3]
process(x)

# Test 2: Empty list
y = []

# Test 3: Typed empty list
z: list[int] = []

# Test 4: Nested lists
matrix = [[1, 2], [3, 4]]

# Test 5: Function argument
process([1, 2, 3])
"""
    # Expected fragments in V output
    expected = [
        "x := [1, 2, 3]",
        "y := []Any{}",
        "z := []int{}",
        "matrix := [[1, 2], [3, 4]]",
        "process([1, 2, 3])"
    ]
    transpile_and_verify(code, expected)

def test_list_comprehension_simple():
    code = "x = [i for i in range(10)]"
    # We might keep the current implementation for comprehensions as it is more robust
    # but the task asks to use [for ...] syntax if possible.
    # Let's see what the task asks for specifically.
    # "List comprehensions use [for ...] syntax"
    expected = ["x := [for i in 0..10 { i }]"]
    transpile_and_verify(code, expected)

def test_pre_allocated_list():
    code = "zeros = [0] * 10"
    expected = ["zeros := []int{len: 10, init: 0}"]
    transpile_and_verify(code, expected)
