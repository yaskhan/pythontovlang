# Py2V Transpiler Extra Features Issues

The following issues were identified while transpiling Python code containing the walrus operator (`:=`), `for...else` loops, and complex list comprehensions.

### 1. `len()` Built-in Function Translation
**Description:**
When transpiling `len(data)` on a list, the transpiler generates `len(data)` in V. However, V does not have a global `len()` function. Instead, length is an array/string property accessed via `.len` (e.g., `data.len`).

**Expected Behavior:**
The transpiler should map calls to the Python built-in `len(obj)` to `obj.len` for strings, arrays, and maps in V.

**Output from V compiler:**
```
test_extra_features.v:4:10: error: unknown function: len
    2 |
    3 | pub fn walrus_test(data []int) {
    4 |     n := len(data)
      |          ~~~~~~~~~
```

### 2. Internal Variable Naming Conventions (`for...else`)
**Description:**
To support Python's `for...else` construct, the transpiler generates a boolean flag variable named `_loop_completed_0`. However, as identified in previous reports, V strictly forbids variables from starting with an underscore (`_`), resulting in a compiler error.

**Expected Behavior:**
The transpiler should generate internal tracking variables using a valid V identifier format (e.g., `loop_completed_0` or `py_loop_completed_0`) that does not start with an underscore.

**Output from V compiler:**
```
test_extra_features.v:10:9: error: variable name `_loop_completed_0` cannot start with `_`
    8 | }
    9 | pub fn loop_else_test(data []int, target int) {
   10 |     mut _loop_completed_0 := true
      |         ~~~~~~~~~~~~~~~~~
```

### 3. Broken Complex List Comprehensions
**Description:**
When translating a complex list comprehension with multiple `for` clauses and `if` conditions (e.g., `[num for row in matrix for num in row if num % 2 == 0]`), the transpiler completely breaks down. It only generates the very first outer loop (`for row in matrix {`) and then immediately tries to append `num` without generating the inner loop or the `if` condition. This leads to undefined variable errors and logically incorrect code.

**Expected Behavior:**
The transpiler must recursively unroll complex list comprehensions into nested V `for` loops and `if` blocks. For the above example, it should generate:
```v
for row in matrix {
    for num in row {
        if num % 2 == 0 {
            flat_even << num
        }
    }
}
```

**Output from V compiler:**
```
test_extra_features.v:28:9: warning: unused variable: `row`
   26 |     matrix << [7, 8, 9]
   27 |     mut flat_even := []int{}
   28 |     for row in matrix {
      |         ~~~
   29 |         flat_even << num
   30 |     }

test_extra_features.v:29:22: error: undefined ident: `num`
   27 |     mut flat_even := []int{}
   28 |     for row in matrix {
   29 |         flat_even << num
      |                      ~~~
```