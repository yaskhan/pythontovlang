# Transpilation Issues Report

This report documents issues found during the transpilation of Python test files to V using `py2v`.

## 1. test_slice_ops.py

### Issues Found:
- **Invalid Delete Call**: In `test_slice_delete`, the Python `del lst[2:5]` was transpiled to `lst.delete(None)`. `None` is not a valid V value (should be `none`), and V's `delete` method requires an index or a range, not `None`.
- **Negative Indexing in Slices**: In `test_slice_out_of_bounds`, `lst[-100:100]` became `lst[lst.len - 100..100]`. If `lst.len < 100`, the start index becomes negative, which causes a runtime panic in V. Python handles this by clamping the index to 0.
- **Type Mismatch in Slicing**: `py_list_slice` is used for both lists and strings. While it might be a generic helper, strings in V are not strictly compatible with `[]T` helpers without proper overloading or casting.

## 2. test_tuple_type.py

### Issues Found:
- **Incorrect Casting**: In `test_tuple_methods`, the code `(t as none).count(2)` is generated. `none` is a keyword in V, not a type, making this an invalid cast.
- **Invalid Array Initialization**: `mut t3 := []Any([1, 2, 3])` is generated for `tuple([1, 2, 3])`. V does not support this syntax for creating an array from another array.
- **Method Mapping Error**: Python's `.append()` was transpiled to `.append()` in V (e.g., `t2[0].append(3)`), but V uses the `<<` operator for appending to arrays.
- **Tuple to Array Mapping**: Python tuples are transpiled to V arrays (`[]T`), which are mutable in V. This loses the immutability property of Python tuples.

## 3. test_range_type.py

### Issues Found:
- **Invalid Casting to Set**: For `set(r)`, the transpiler generated `map[string]bool(r)`. This is invalid because `r` is a `[]int`, and V does not support direct casting from an array to a map.
- **Invalid Array Cast**: `[]Any(r)` is used to convert `[]int` to `[]Any`. V requires an explicit map call or loop to convert element types in an array.

## 4. test_global_nonlocal.py

### Issues Found:
- **Missing Closure Captures**: In `test_global_variable`, the anonymous function `increment` accesses and modifies `counter` from the outer scope without capturing it. V requires explicit capture: `fn [mut counter] () { ... }`.
- **Incorrect Type Inference/Cast**: In `test_closure_in_loop`, the generated code includes `(funcs as string).append(func)`. `funcs` was correctly identified as an array (`[]Any`), but then incorrectly cast to `string` to call an `append` method (which doesn't exist on strings in that form either).
- **Mutating Captures**: V's closure capture syntax `fn [x] ()` captures by value. Modifying a captured variable inside a closure (as in `nonlocal` usage) requires capturing by reference or using a mutable pointer, which the transpiler does not currently handle correctly.

## 5. test_iterators.py

### Issues Found:
- **Invalid Struct Initialization**: In `test_custom_iterator`, `mut self := {}` is generated. V requires a type name for struct initialization.
- **Broken Constructor Logic**: The Python `__init__` was transpiled to a local function named `new_`, but the call site used `new_counter`, leading to a "function not found" error.
- **Invalid Iterator Consumption**: `remaining := []Any(it)` was generated for `list(it)`. V does not support casting an iterator directly to an array.
- **Type Inference Failure**: In `next`, the code `(self as builtins.list[string]).current` was generated. `builtins.list[string]` is not a valid V type.
- **StopIteration Handling**: The transpiler uses `vexc.raise('StopIteration', '')`, which depends on a non-standard `div72.vexc` module, making the code non-idiomatic and potentially non-functional without external dependencies.
