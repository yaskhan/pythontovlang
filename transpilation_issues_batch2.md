# Issues found during transpilation - Batch 2

## Files analyzed

1. test_classes_inheritance.py
2. test_comprehensions.py
3. test_decorators.py
4. test_dict_operations.py
5. test_exceptions.py
6. test_function_defs.py
7. test_if_statement.py
8. test_list_operations.py
9. test_args_kwargs.py
10. test_context_managers.py
11. test_for_loop.py
12. test_lambda_functions.py
13. test_string_methods.py

---

## Issue #1: Polymorphism with mixed types in array

**File:** test_classes_inheritance.py

**Python code:**
```python
def test_polymorphism():
    animals: list[Animal] = [Dog("Rex", "Shepherd"), Cat("Whiskers")]
    for animal in animals:
        print(f"{animal.name} says: {animal.speak()}")
```

**Generated V code:**
```v
animals := [new_dog('Rex', 'Shepherd'), new_cat('Whiskers')]
for animal in animals {
    println('${animal.name} says: ${animal.speak()}')
}
```

**Problem:**
- In V, arrays cannot contain different struct types. The array `[Dog, Cat]` will not compile.
- The transpiler should either use `[]Any` or a sum type to handle polymorphic collections.

---

## Issue #2: `issubclass()` generates comment instead of code

**File:** test_classes_inheritance.py

**Python code:**
```python
print(f"Dog is subclass of Animal: {issubclass(Dog, Animal)}")
```

**Generated V code:**
```v
println('Dog is subclass of Animal: ${/* issubclass(Dog, Animal) */ true}')
```

**Problem:**
- `issubclass()` is replaced with a comment and hardcoded `true`/`false` values.
- The actual runtime check is lost.

---
*****************************
## * Issue #3: Class variables not supported in V

**File:** test_classes_inheritance.py

**Python code:**
```python
class Vehicle:
    wheels = 4  # Class variable
```

**Generated V code:**
```v
pub struct Vehicle {
    wheels int = 4
    brand string
}

pub const Vehicle_wheels = 4
```

**Problem:**
- V does not have class variables in Python style. The field `wheels int = 4` is an instance field with default value, not a class variable.
- The separate constant `Vehicle_wheels` is generated but changes to the class variable won't be reflected.

---

## Issue #4: Set comprehension uses `map[T]bool` instead of native set

**File:** test_comprehensions.py

**Python code:**
```python
unique_squares = {x * x for x in range(-3, 4)}
```

**Generated V code:**
```v
mut unique_squares := map[int]bool{}
for x in -3..4 {
    unique_squares[x * x] = true
}
```

**Problem:**
- V has native sets (`[]T{}` with `.add()`), but the transpiler uses `map[int]bool`.
- This is not idiomatic V and loses set semantics.

---

## Issue #5: Generator expressions converted to eager arrays

**File:** test_comprehensions.py

**Python code:**
```python
gen = (x * x for x in range(5))
for val in gen:
    print(val)
```

**Generated V code:**
```v
mut gen := []int{cap: 5}
for x in 0..5 {
    gen << x * x
}
for val in gen {
    println('${val}')
}
```

**Problem:**
- Python generators are lazy, but the V code eagerly builds an array.
- This changes memory semantics for large sequences.

---

## Issue #6: Tuples in comprehensions use arrays instead of tuple structs

**File:** test_comprehensions.py

**Python code:**
```python
pairs = [(x, y) for x in range(3) for y in range(3)]
```

**Generated V code:**
```v
mut pairs := [][]int{cap: 3}
for x in 0..3 {
    for y in 0..3 {
        pairs << [x, y]
    }
}
```

**Problem:**
- Python tuples are immutable and fixed-size, but V arrays are mutable.
- The transpiler should use `TupleStruct_IntInt` for type safety.

---

## Issue #7: Decorator closures use invalid capture syntax

**File:** test_decorators.py

**Python code:**
```python
def decorator(func):
    def wrapper():
        print("Before")
        func()
        print("After")
    return wrapper
```

**Generated V code:**
```v
mut decorator := fn (func fn (...Any) Any) fn (...Any) Any {
    mut wrapper := fn [func] () {
        println('Before')
        func()
        println('After')
    }
    return wrapper
}
```

**Problem:**
- The `[func]` capture syntax is not valid V.
- V closures cannot capture mutable variables from outer scope in this way.

---

## Issue #8: `__name__` and `__doc__` attributes generate invalid syntax

**File:** test_decorators.py

**Python code:**
```python
print(f"Name: {original_func.__name__}")
print(f"Doc: {original_func.__doc__}")
```

**Generated V code:**
```v
println('Name: ${original_func____name__}')
println('Doc: ${original_func____doc__}')
```

**Problem:**
- `original_func____name__` is not valid V syntax.
- V functions do not have `__name__` or `__doc__` attributes.

---

## Issue #9: Property setter has incorrect return type

**File:** test_decorators.py

**Python code:**
```python
@celsius.setter
def celsius(self, value: float):
    if value < -273.15:
        raise ValueError("Below absolute zero")
    self._celsius = value
```

**Generated V code:**
```v
pub fn (mut self Temperature) set_celsius(value f64) f64 {
    if value < -273.15 {
        vexc.raise('ValueError', 'Below absolute zero')
    }
    self._celsius = value
}
```

**Problem:**
- The setter returns `f64` but does not return a value.
- Python setters should not return anything (implicit `None`).

---

## Issue #10: `dict.clear()` replaced with reassignment

**File:** test_dict_operations.py

**Python code:**
```python
d.clear()
print(f"Cleared: {d}")
```

**Generated V code:**
```v
/* d.clear() */ d = {}
println('Cleared: ${d}')
```

**Problem:**
- `d.clear()` is commented out and replaced with `d = {}`.
- If `d` is passed by reference elsewhere, this creates a new map instead of clearing the existing one.

---

## Issue #11: `dict.fromkeys()` with mutable default value

**File:** test_dict_operations.py

**Python code:**
```python
d2 = dict.fromkeys(keys, [])
```

**Generated V code:**
```v
mut d2 := py_dict_fromkeys<map[string]int>(keys, []Any{}).clone()
```

**Problem:**
- In Python, `dict.fromkeys(keys, [])` shares the same list object for all keys.
- The V code uses `[]Any{}` which is also shared, but the semantics may differ.
- The `.clone()` call may not work correctly with `py_dict_fromkeys`.

---

## Issue #12: `try/except` requires C interop and external library

**File:** test_exceptions.py

**Python code:**
```python
try:
    result = 10 / 2
except ZeroDivisionError:
    print("Division by zero!")
```

**Generated V code:**
```v
import div72.vexc

if C.try() {
    mut result := 10 / 2
    vexc.end_try()
} else {
    py_exc_1 := vexc.get_curr_exc()
    if py_exc_1.name == 'ZeroDivisionError' {
        println('Division by zero!')
    }
    else {
        vexc.raise(py_exc_1.name, py_exc_1.msg)
    }
}
```

**Problem:**
- Requires `div72.vexc` external library.
- Uses `C.try()` which is not idiomatic V.
- V prefers `Result`/`Option` types with `or { ... }` syntax.

---

## Issue #13: `assert` message lost

**File:** test_exceptions.py

**Python code:**
```python
assert x == 5, "x should be 5"
```

**Generated V code:**
```v
assert x == 5
```

**Problem:**
- The assertion message "x should be 5" is lost.
- V's `assert` does not support custom messages.

---

## Issue #14: `__cause__` attribute not available in V

**File:** test_exceptions.py

**Python code:**
```python
print(f"__cause__: {e.__cause__}")
```

**Generated V code:**
```v
println('__cause__: ${e.__cause__}')
```

**Problem:**
- `e.__cause__` is not valid V syntax.
- V exceptions do not have a `__cause__` attribute.

---

## Issue #15: Default parameter values lost

**File:** test_function_defs.py

**Python code:**
```python
def greet(name: str, greeting: str = "Hello"):
    print(f"{greeting}, {name}!")

greet("Alice")
```

**Generated V code:**
```v
mut greet := fn (name string, greeting string) {
    println('${greeting}, ${name}!')
}
greet('Alice', 'Hello')
```

**Problem:**
- The default value `greeting: str = "Hello"` is lost.
- The call `greet("Alice")` is changed to `greet('Alice', 'Hello')` with explicit argument.
- V does not support default parameters in the same way.

---

## Issue #16: Keyword argument order changed

**File:** test_function_defs.py

**Python code:**
```python
describe(age=25, city="LA", name="Bob")
```

**Generated V code:**
```v
describe('Bob', 25, 'LA')
```

**Problem:**
- Python keyword arguments allow any order, but V requires positional order.
- The transpiler reorders arguments but loses the keyword argument semantics.

---

## Issue #17: Multiple returns converted to array

**File:** test_function_defs.py

**Python code:**
```python
def min_max(nums):
    return min(nums), max(nums)

min_val, max_val = min_max([3, 1, 4, 1, 5, 9])
```

**Generated V code:**
```v
mut min_max := fn (nums Any) Any {
    return [py_min(nums), py_max(nums)]
}

py_destruct_0 := min_max([3, 1, 4, 1, 5, 9])
min_val := py_destruct_0[0]
max_val := py_destruct_0[1]
```

**Problem:**
- Python returns a tuple, but V code returns an array.
- Destructuring uses `[]` indexing which doesn't work for V tuples.

---

## * Issue #18: `not x` for boolean converted to `x == 0`

**File:** test_if_statement.py

**Python code:**
```python
x = False
if not x:
    print("x is False")
```

**Generated V code:**
```v
mut x := false
if x == 0 {
    println('x is False')
}
```

**Problem:**
- `not x` should be `!x` in V, not `x == 0`.
- Comparing boolean to integer `0` is not idiomatic.

---

## Issue #19: `?string` variable assigned string values

**File:** test_if_statement.py

**Python code:**
```python
score = 85
if score >= 90:
    grade = "A"
elif score >= 80:
    grade = "B"
```

**Generated V code:**
```v
score := 85
mut grade := ?string(none)
if score >= 90 {
    grade = 'A'
} else if score >= 80 {
    grade = 'B'
}
```

**Problem:**
- `grade` is typed as `?string` but assigned plain strings `'A'`, `'B'`.
- In V, you need `?string('A')` or change the type to `string`.

---

## Issue #20: `list.extend()` adds list as single element

**File:** test_list_operations.py

**Python code:**
```python
lst.extend([5, 6, 7])
```

**Generated V code:**
```v
lst << [5, 6, 7]
```

**Problem:**
- In V, `<<` adds the entire array as a single element.
- Python's `extend()` adds each element individually.
- The correct V code would need a loop or `lst << [5, 6, 7]...` syntax.

---

## Issue #21: `list.clear()` replaced with reassignment

**File:** test_list_operations.py

**Python code:**
```python
lst.clear()
```

**Generated V code:**
```v
/* lst.clear() */ lst = []
```

**Problem:**
- Same issue as `dict.clear()` - creates a new array instead of clearing existing one.

---

## Issue #22: `sort(key=len)` loses key function

**File:** test_list_operations.py

**Python code:**
```python
words = ["banana", "pie", "Washington", "book"]
words.sort(key=len)
```

**Generated V code:**
```v
words := ['banana', 'pie', 'Washington', 'book']
words.sort()
```

**Problem:**
- The `key=len` parameter is lost.
- Words are sorted lexicographically instead of by length.

---

## Issue #23: Slice assignment with step not supported

**File:** test_list_operations.py

**Python code:**
```python
lst[::2] = [100, 200, 300]
```

**Generated V code:**
```v
lst.delete_many(0, (lst.len) - (0))
lst.insert_many(0, [100, 200, 300])
```

**Problem:**
- This replaces the entire list instead of every 2nd element.
- V does not support slice assignment with step.

---

## Issue #24: Extended unpacking uses invalid indexing

**File:** test_list_operations.py

**Python code:**
```python
first, *middle, last = [1, 2, 3, 4, 5]
```

**Generated V code:**
```v
py_destruct_0 := [1, 2, 3, 4, 5]
first := py_destruct_0[0]
middle := py_destruct_0[1..py_destruct_0.len-1]
last := py_destruct_0[py_destruct_0.len-1]
```

**Problem:**
- Uses `[]` indexing which may not work for all V types.
- The slicing `[1..len-1]` excludes the last element, but Python's `*middle` includes all middle elements.

---

## Issue #25: Variadic parameter type fixed to `int`

**File:** test_args_kwargs.py

**Python code:**
```python
def print_args(*args):
    for arg in args:
        print(f"arg={arg}")

print_args("a", "b", "c")
```

**Generated V code:**
```v
mut print_kwargs := fn (kwargs map[string]int) {
    for key, value in kwargs {
        println('${key}=${value}')
    }
}
print_kwargs({'name': 'Alice', 'age': 30})
```

**Problem:**
- The variadic parameter is typed as `...int` but called with strings.
- The kwargs are typed as `map[string]int` but called with mixed types.

---

## Issue #26: Positional-only and keyword-only parameters ignored

**File:** test_args_kwargs.py

**Python code:**
```python
def func(a, b, /, c, d):
    print(f"a={a}, b={b}, c={c}, d={d}")

func(1, 2, c=3, d=4)
```

**Generated V code:**
```v
mut func := fn (a Any, b Any, c Any, d Any) {
    println('a=${a}, b=${b}, c=${c}, d=${d}')
}
func(1, 2)
```

**Problem:**
- The `/` (positional-only) and `*` (keyword-only) markers are ignored.
- All parameters become regular positional parameters.

---

## Issue #27: `**kwargs` unpacking not supported

**File:** test_args_kwargs.py

**Python code:**
```python
kwargs = {"a": 1, "b": 2, "c": 3}
func(**kwargs)
```

Generated V code:
```v
mut kwargs := {'a': 1, 'b': 2, 'c': 3}
func(kwargs)
```

**Problem:**
- `**kwargs` should unpack the dictionary as keyword arguments.
- The V code passes the entire dictionary as a single argument.

---

## Issue #28: Context manager `__enter__`/`__exit__` renamed

**File:** test_context_managers.py

**Python code:**
```python
class SimpleContext:
    def __enter__(self):
        print("Entering")
        return self
    
    def __exit__(self, *args):
        print("Exiting")
```

**Generated V code:**
```v
pub fn (self SimpleContext) enter() Any {
    println('Entering')
    return self
}

pub fn (self SimpleContext) exit(args ...int) bool {
    println('Exiting')
}
```

**Problem:**
- `__enter__` and `__exit__` are renamed to `enter` and `exit`.
- These are not standard V context manager methods.
- The `exit` method has variadic `args ...int` which may not match all exception types.

---

## * Issue #29: `for/else` loses else semantics

**File:** test_for_loop.py

**Python code:**
```python
for i in range(3):
    print(f"i={i}")
else:
    print("For loop completed normally")
```

**Generated V code:**
```v
for i in 0..3 {
    println('i=${i}')
}
println('For loop completed normally')
```

**Problem:**
- In Python, the `else` clause only executes if the loop completes without `break`.
- The V code always executes the "else" block.

---

## Issue #30: `zip()` implementation may overflow

**File:** test_for_loop.py

**Python code:**
```python
for name, age in zip(names, ages):
    print(f"{name} is {age}")
```

**Generated V code:**
```v
py_zip_it1_1 := names
py_zip_it2_1 := ages
for py_i_1, py_v1_1 in py_zip_it1_1 {
    if py_i_1 >= py_zip_it2_1.len { break }
    py_v2_1 := py_zip_it2_1[py_i_1]
    name := py_v1_1
    age := py_v2_1
    println('${name} is ${age}')
}
```

**Problem:**
- Uses index-based iteration which may not work correctly with all iterator types.
- The `break` when index exceeds length is correct but not idiomatic.

---

## Issue #31: Tuple unpacking in `for` uses invalid indexing

**File:** test_for_loop.py

**Python code:**
```python
pairs = [(1, 2), (3, 4), (5, 6)]
for a, b in pairs:
    print(f"a={a}, b={b}")
```

**Generated V code:**
```v
pairs := [[1, 2], [3, 4], [5, 6]]
for py_val_2175032263952 in pairs {
    a := py_val_2175032263952[0]
    b := py_val_2175032263952[1]
    println('a=${a}, b=${b}')
}
```

**Problem:**
- Uses `[]` indexing which doesn't work for V tuples.
- The variable name `py_val_2175032263952` is auto-generated and ugly.

---

## * Issue #32: Lambda default values lost

**File:** test_lambda_functions.py

**Python code:**
```python
power = lambda x, n=2: x ** n
print(power(5))
```

**Generated V code:**
```v
power := fn (x int, n int) int { return int(math.powi(f64(x), n)) }
println('${power(5)}')
```

**Problem:**
- The default value `n=2` is lost.
- The call `power(5)` is changed to `power(5, <missing>)` which will not compile.

---

## Issue #33: `sorted(key=lambda)` loses key function

**File:** test_lambda_functions.py

**Python code:**
```python
sorted_pairs = sorted(pairs, key=lambda x: x[1])
```

**Generated V code:**
```v
sorted_pairs := py_sorted(pairs)
```

**Problem:**
- The `key=lambda x: x[1]` parameter is lost.
- The list is sorted by default comparison instead of by second element.

---

## Issue #35: Lambda list comprehension with late binding

**File:** test_lambda_functions.py

**Python code:**
```python
funcs = [lambda x, i=i: x + i for i in range(5)]
```

**Generated V code:**
```v
mut funcs := []int{cap: 5}
for i in 0..5 {
    funcs << fn (x int, i int) int { return x + i }
}
```

**Problem:**
- In Python, `i=i` captures the current value of `i` at definition time.
- The V code does not capture `i` - all lambdas will use the final value of `i`.

---

## Issue #36: `str.format()` not supported

**File:** test_string_methods.py

**Python code:**
```python
msg = "My name is {} and I am {}".format(name, age)
```

**Generated V code:**
```v
msg := /* 'My name is {} and I am {}'.format(...) */ 'My name is {} and I am {}' //##LLM@@ .format() is not supported, use interpolation
```

**Problem:**
- `str.format()` is commented out and replaced with the unformatted string.
- V does not have a `format()` method for strings.

---

## Issue #37: `split_nth()` and `replace_n()` may not exist

**File:** test_string_methods.py

**Python code:**
```python
limited = text.split(",", 1)
replaced2 = s2.replace("a", "x", 3)
```

**Generated V code:**
```v
limited := text.split_nth(',', 1 + 1)
replaced2 := s2.replace_n('a', 'x', 3)
```

**Problem:**
- `split_nth()` and `replace_n()` may not exist in V's string library.
- The transpiler should verify method availability or use helpers.

---

## Issue #38: Negative string indexing uses helper function

**File:** test_string_methods.py

**Python code:**
```python
print(s[-3:])
```

**Generated V code:**
```v
println('${py_str_slice(s, -3, none, none)}')
```

**Problem:**
- V does not support negative string indexing natively.
- The helper function `py_str_slice` may not exist or work correctly.

---

## * Issue #40: String character checks use `bytes()` iteration

**File:** test_string_methods.py

**Python code:**
```python
print(s1.isalnum())
```

**Generated V code:**
```v
println('${s1.bytes().all(it.is_alnum())}')
```

**Problem:**
- Uses `bytes().all()` which iterates over byte values.
- This is not idiomatic V and may not work correctly for Unicode strings.

---

## Summary

| Severity | Count | Examples |
|----------|-------|---------|
| High | 22 | Polymorphism arrays, decorator captures, default values lost, string format |
| Medium | 13 | Set comprehension, generator semantics, slice assignment, lambda capture |
| Low | 5 | Class variables, context manager rename, string checks |

### Critical issues requiring immediate attention:
1. Polymorphic arrays (#1)
2. Decorator closure capture syntax (#7)
3. Default parameter values lost (#15)
4. `str.format()` not supported (#36)
5. Lambda capture syntax (#34)
6. `for/else` semantics (#29)
7. Variadic parameter typing (#25)