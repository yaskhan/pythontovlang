# Issues found during transpilation of unchecked files

## Files analyzed

1. test_features.py
2. test_more_features.py
3. test_misc_features.py
4. test_final_features.py
5. test_even_more_features.py
6. test_advenced.py
7. test_function_annotations.py
8. test_type_annotations.py
9. test_string_literals.py
10. test_none_type.py
11. test_transpile.py
12. repro_iterators.py
13. generics_monomorphization.py

---
****************
## * Issue #1: Decorator functions with *args and **kwargs generate invalid V code

**File:** test_more_features.py

**Python code:**
```python
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
```

**Generated V code:**
```v
pub fn my_decorator(func fn (...Any) Any) Any {
    mut wrapper := fn [func] (args ...int, kwargs map[string]string) Any {
        println('Before call')
        result := func(...args, kwargs)
        println('After call')
        return result
    }
    return wrapper
}
```

**Problems:**
- The closure syntax `fn [func] (...)` is not valid V syntax for capturing variables.
- The variadic parameter `args ...int` must be the last parameter in V, but `kwargs map[string]string` follows it.
- `func(...args, kwargs)` - V does not support passing a map as a separate positional argument after variadic args.
- The `@my_decorator` annotation is generated as a comment, but the decorator is not actually applied to `greet`. The `greet` function is generated as a standalone function without the decorator wrapper.
- **Warning issued:** `Warning: Custom decorator 'my_decorator' at line 13 is not fully supported and might generate invalid code.`

---

## Issue #2: Async/Await not supported - generates invalid comments instead of code

**File:** test_more_features.py

**Python code:**
```python
async def fetch_data(id: int) -> str:
    print(f"Fetching {id}...")
    await asyncio.sleep(0.1)
    return f"Data_{id}"

async def main_async():
    data = await fetch_data(42)
    print(data)
```

**Generated V code:**
```v
pub fn fetch_data(id int) string {
    println('Fetching ${id}...')
    /* await */ asyncio.sleep(0.1)
    return 'Data_${id}'
}

pub fn main_async() {
    data := /* await */ fetch_data(42)
    println('${data}')
}
```

**Problems:**
- `await` is replaced with a comment `/* await */` instead of actual V async code.
- `asyncio.sleep(0.1)` and `asyncio.run(main_async())` are not valid V code.
- V does not have built-in async/await support like Python. The transpiler should either use V's `go` routines or emit a clear error.

---

## Issue #3: Chained assignment semantics changed with `.clone()`

**File:** test_misc_features.py

**Python code:**
```python
p = q = r = [1, 2, 3]
p.append(4)
print(f"q: {q}, r: {r}")
```

**Generated V code:**
```v
py_assign_tmp_0 := [1, 2, 3]
mut p := py_assign_tmp_0.clone()
q := py_assign_tmp_0
r := py_assign_tmp_0
p << 4
println('q: ${q}, r: ${r}')
```

**Problem:**
- In Python, `p = q = r = [1, 2, 3]` creates three references to the same list. Appending to `p` also affects `q` and `r`.
- In the generated V code, `p` gets `.clone()` making it an independent copy, while `q` and `r` share the original. This changes the semantics - modifying `p` does not affect `q` or `r`.

---

## Issue #4: Global variables require `-enable-globals` flag

**File:** test_final_features.py

**Python code:**
```python
counter = 0

def increment():
    global counter
    counter += 1
    print(f"Counter: {counter}")
```

**Generated V code:**
```v
// To compile with globals, use: v -enable-globals .
__global counter int

pub fn increment() {
    //##LLM@@ Python 'global' or 'nonlocal' scope modification detected. V heavily discourages global state and has strict mutability rules for closures. Please refactor state management, possibly by passing mutable parameters (mut) explicitly.
    counter += 1
    println('Counter: ${counter}')
}
```

**Problems:**
- V requires the `-enable-globals` flag to compile code with global variables.
- V discourages global state. The transpiler emits a warning comment but does not provide an alternative solution.
- The `init()` function for initializing the global variable may not be called automatically in all contexts.

---

## Issue #5: Context manager methods renamed incorrectly

**File:** test_final_features.py

**Python code:**
```python
class MyContext:
    def __enter__(self):
        print("Entering context")
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        print("Exiting context")

def process():
    with MyContext() as ctx:
        print("Inside context")
        increment()
```

**Generated V code:**
```v
pub fn (self MyContext) enter() Any {
    println('Entering context')
    return self
}

pub fn (self MyContext) exit(exc_type Any, exc_val Any, exc_tb Any) {
    println('Exiting context')
}

pub fn process() {
    ctx_mgr_0 := MyContext{}
    defer { ctx_mgr_0.exit(none, none, none) }
    ctx := ctx_mgr_0.enter()
    println('Inside context')
    increment()
}
```

**Problems:**
- `__enter__` is renamed to `enter` and `__exit__` is renamed to `exit`. These are not standard V context manager methods.
- The `enter()` method returns `Any` instead of the specific type `MyContext`.
- The `with` statement is translated using `defer`, which is functional but not idiomatic for V context management.

---

## Issue #6: Property setter returns a value (invalid in Python semantics)

**File:** test_even_more_features.py

**Python code:**
```python
@full_name.setter
def full_name(self, value: str):
    parts = value.split(" ")
    if len(parts) == 2:
        self._first = parts[0]
        self._last = parts[1]
```

**Generated V code:**
```v
pub fn (mut self User) set_full_name(value string) string {
    parts := value.split(' ')
    if parts.len == 2 {
        self._first = py_subscript(parts, 0)
        self._last = py_subscript(parts, 1)
    }
}
```

**Problems:**
- The setter function has return type `string` but does not return a value. In V, this may cause a compilation error.
- Python setters should not return a value. The transpiler should generate a function with no return type.
- `py_subscript(parts, 0)` is used instead of `parts[0]`. While this may work, it is not idiomatic V.

---

## Issue #7: Match/case with Union type may fail at runtime

**File:** test_even_more_features.py

**Python code:**
```python
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

match_status(500)  # This should work in Python
```

**Generated V code:**
```v
pub fn match_status(status SumType_IntString) {
    py_match_subject_1 := status
    py_match_subject_any_1 := Any(py_match_subject_1)
    mut py_match_found_1 := false
    if !py_match_found_1 && (py_match_subject_any_1 == 200) {
        println('OK')
        py_match_found_1 = true
    }
    // ... more cases
}

match_status(500)  # This will fail in V
```

**Problems:**
- The function signature requires `SumType_IntString`, but `match_status(500)` passes a plain `int`.
- In V, you cannot pass a plain `int` to a function expecting `SumType_IntString` without explicit wrapping.
- The match statement is converted to a series of `if` blocks with `Any` comparisons, which loses type safety.

---


*******************
## * Issue #9: Tuple destructuring uses invalid indexing syntax

**File:** test_function_annotations.py, test_type_annotations.py, test_string_literals.py

**Python code:**
```python
x, y = coords
```

**Generated V code:**
```v
py_destruct_0 := coords
x := py_destruct_0[0]
y := py_destruct_0[1]
```

**Problem:**
- `TupleStruct_IntInt` does not support indexing via `[]`. V tuples use named fields like `.it_0`, `.it_1` or field names.
- The generated code will not compile in V.

---
*****************************
## * Issue #10: `mut none` is invalid V syntax

**File:** test_function_annotations.py

**Python code:**
```python
def process(name: str, nums: Optional[List[int]] = None, multiplier: int = 1) -> List[int]:
    if nums is None:
        nums = []
    return [x * multiplier for x in nums]

process("test")  # Uses default None for nums
```

**Generated V code:**
```v
pub fn process(name string, nums ?[]int, multiplier int) []int {
    if nums == none {
        nums = []int{}
    }
    mut py_comp_3 := []int{}
    for x in nums {
        py_comp_3 << x * multiplier
    }
    return py_comp_3
}

process('test', mut none, 1)
```

**Problems:**
- `mut none` is not valid V syntax.
- The default parameter handling is incorrect - instead of using V's default parameter syntax, the transpiler explicitly passes `mut none` at call sites.
- V does not support default parameter values in the same way as Python.

---
****************************
## * Issue #11: `extend()` translated as `<<` which adds list as single element

**File:** test_type_annotations.py

**Python code:**
```python
def complex_dict(data: Dict[str, List[int]]) -> List[int]:
    result: List[int] = []
    for key, values in data.items():
        result.extend(values)
    return result
```

**Generated V code:**
```v
pub fn complex_dict(data map[string][]int) []int {
    mut result := []int{}
    for key, values in data {
        result << values
    }
    return result
}
```

**Problem:**
- `result << values` adds the entire `values` list as a single element to `result`, rather than extending `result` with each element of `values`.
- In Python, `result.extend(values)` adds each element individually.
- The correct V code would need a nested loop or array spreading.

---
******************************
## * Issue #12: `callable` type annotation generates untyped `fn`

**File:** test_type_annotations.py

**Python code:**
```python
def function_type(f: callable, x: int) -> int:
    return f(x)

def apply_function(f: callable, values: List[int]) -> List[int]:
    result: List[int] = []
    for v in values:
        result.append(f(v))
    return result
```

**Generated V code:**
```v
pub fn function_type(f fn, x int) int {
    return f(x)
}

pub fn apply_function(f fn, values []int) []int {
    mut result := []int{}
    for v in values {
        result << f(v)
    }
    return result
}
```

**Problem:**
- `fn` without a signature is not type-safe in V.
- The function `f` cannot be called without knowing its parameter and return types.
- V requires explicit function signatures like `fn (int) int`.


---
**************************
## Issue #14: `format_map()` method does not exist in V

**File:** test_string_literals.py

**Python code:**
```python
data = {"name": "Bob", "age": 25}
result = "{name} is {age} years old".format_map(data)
```

**Generated V code:**
```v
data := {'name': Any('Bob'), 'age': Any(25)}
mut result := '{name} is {age} years old'.format_map(data)
```

**Problem:**
- V strings do not have a `format_map()` method.
- The transpiler should either use V's string interpolation or a helper function.

---

## Issue #15: NoneType handling generates invalid V code

**File:** test_none_type.py

**Python code:**
```python
x = None
y = 10
x = y
y = None
```

**Generated V code:**
```v
mut x := Any(NoneType{})
mut y := 10
x = y
y = none
```

**Problems:**
- `Any(NoneType{})` is not valid V syntax.
- `NoneType{}` is not a valid V type or constructor.
- Assigning `none` to an `int` variable (`y = none`) will not compile in V.

---

## Issue #16: Function returning void assigned to variable

**File:** test_none_type.py

**Python code:**
```python
def no_return():
    pass

result = no_return()
print(f"No return result: {result}")
print(f"Is None: {result is None}")
```

**Generated V code:**
```v
mut no_return := fn () {
}
mut result := no_return()
println('No return result: ${result}')
println('Is None: ${(result) is NoneType}')
```

**Problem:**
- In V, a function without a return statement returns `void`, not `none`.
- Assigning `void` to a variable and printing it is not valid in V.
- The transpiler should either make the function return `?` or handle this case differently.

---

## Issue #17: `mut` keyword used in function parameters

**File:** test_none_type.py

**Python code:**
```python
def get_value(x=None):
    return "No value" if x is None else f"Value: {x}"
```

**Generated V code:**
```v
mut get_value := fn (mut x Any) Any {
    return if (x) is NoneType { 'No value' } else { 'Value: ${x}' }
}
```

**Problem:**
- `mut` in function parameters is not idiomatic V for this use case.
- The function parameter should not be mutable unless explicitly needed.

---
*************************
## * Issue #18: SumType methods not available without type narrowing

**File:** test_transpile.py

**Python code:**
```python
class Data:
    def __init__(self):
        self.value: int | str = 0

d = Data()
d.value = "hello"
print(d.value.upper())

d.value = 123
print(d.value + 1)
```

**Generated V code:**
```v
pub struct Data {
    value SumType_IntString
}

d := new_data()
d.value = 'hello'
println('${d.value.to_upper()}')
d.value = 123
println('${d.value + 1}')
```

**Problems:**
- `d.value.to_upper()` - `SumType_IntString` does not have a `to_upper()` method. You must first narrow the type to `string`.
- `d.value + 1` - `SumType_IntString` does not support `+` with `int`. You must first narrow the type to `int`.
- The transpiler should generate type narrowing checks before accessing type-specific methods or operators.

---

## * Issue #19: `py_list_from_iter` with custom iterator may fail

**File:** repro_iterators.py

**Python code:**
```python
data = [1, 2, 3, 4, 5]
it = iter(data)
remaining = list(it)
print(f"Remaining: {remaining}")
```

**Generated V code:**
```v
it := py_iter(data)
remaining := py_list_from_iter<[]Any>(it)
println('Remaining: ${remaining}')
```

**Problem:**
- `py_list_from_iter<[]Any>(it)` may not work correctly with all iterator types.
- The generic type `[]Any` loses type information from the original `List[int]`.

---
**********************
## Issue #20: Generic class field type not preserved

**File:** generics_monomorphization.py

**Python code:**
```python
T = TypeVar("T")

class Box(Generic[T]):
    def __init__(self, x: T):
        self.x = x
```

**Generated V code:**
```v
pub struct Box[T] {
    x int
}

pub fn new_box[T](x T) Box[T] {
    mut self := Box[T]{}
    self.x = x
    return self
}
```

**Problem:**
- The struct field `x` has type `int` hardcoded instead of `T`.
- When `Box[T]` is used with different types (e.g., `Box[string]`), the field type `int` will be incorrect.
- The field should be `x T` to properly support generics.

---

## Summary of Known Issues (from user)

These issues were already known before this analysis:

1. **Variadic parameter must be last in V:** In V, the variadic parameter (`...Any`) must be the last parameter in the argument list.
2. **Cannot assign void function result:** In V, you cannot assign the result of a function that returns nothing (`void`).
3. **Type mismatch in if/elif chains:** Variables defined as `?int` cannot be assigned string values like `'A'`, `'B'`, etc.
4. **C.try() for exceptions:** The transpiler uses `if C.try() { ... } else { ... }` for exception handling, which is not idiomatic V and may require the `div72.vexc` library or C interop.
5. **Limited decorator support:** Custom decorators generate warnings and produce code that may not be valid V. The `@decorator` syntax is not directly supported in V.

---

## Newly Discovered Issues

| # | Issue | Severity | Files Affected |
|---|-------|----------|----------------|
| 1 | Decorator closures with invalid V syntax | High | test_more_features.py |
| 2 | Async/Await not supported (comment-only) | High | test_more_features.py |
| 3 | Chained assignment `.clone()` changes semantics | Medium | test_misc_features.py |
| 4 | Global variables require `-enable-globals` | Medium | test_final_features.py |
| 5 | Context manager methods renamed | Low | test_final_features.py |
| 6 | Property setter has incorrect return type | Medium | test_even_more_features.py |
| 7 | Match/case Union type compatibility | High | test_even_more_features.py |
| 8 | Try/except requires external library | High | test_advenced.py |
| 9 | Tuple destructuring invalid indexing | High | test_function_annotations.py, test_type_annotations.py, test_string_literals.py |
| 10 | `mut none` invalid syntax | High | test_function_annotations.py |
| 11 | `extend()` vs `<<` semantic difference | Medium | test_type_annotations.py |
| 12 | `callable` type untyped `fn` | Medium | test_type_annotations.py |
| 13 | `partition()` invalid tuple indexing | High | test_string_literals.py |
| 14 | `format_map()` not available in V | Medium | test_string_literals.py |
| 15 | `NoneType{}` invalid syntax | High | test_none_type.py |
| 16 | Void function assigned to variable | High | test_none_type.py |
| 17 | `mut` in function parameters | Low | test_none_type.py |
| 18 | SumType methods without narrowing | High | test_transpile.py |
| 19 | `py_list_from_iter` type loss | Low | repro_iterators.py |
| 20 | Generic field type hardcoded | High | generics_monomorphization.py |