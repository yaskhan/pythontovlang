# Py2V Transpiler Advanced Issues

The following issues were identified while transpiling Python code containing advanced features such as closures/nested functions, try/except blocks, and lists with union types.

### 1. External dependencies for exception handling (`div72.vexc`)
**Description:**
When translating Python `try/except/finally` blocks, the transpiler relies on a non-standard V module `div72.vexc` (e.g., `import div72.vexc` and `C.try()`). This package is not part of the standard V library or automatically provided/installed by the transpiler locally, which causes immediate "cannot import module" build failures in V.

**Expected Behavior:**
The transpiler should generate standalone V code using standard V error handling mechanisms (like `Result`/`Option` types or standard error matching) rather than depending on a seemingly missing or custom external library `div72.vexc`.

**Output from V compiler:**
```
test_advanced.v:3:1: builder error: cannot import module "div72.vexc" (not found)
    1 | module main
    2 |
    3 | import div72.vexc
      | ~~~~~~~~~~~~~~~~~
```

### 2. Lack of Support for Closures and Nested Functions
**Description:**
When a nested function (closure) is defined inside another function in Python (e.g. `multiplier` inside `create_multiplier`), the transpiler incorrectly hoists the nested function to the module level as a standalone `pub fn`. This breaks lexical scoping, meaning the inner function cannot access variables from the outer function's scope (e.g. `factor`). Furthermore, the outer function returning the inner function fails to properly type the return value as a V function type.

**Expected Behavior:**
The transpiler should ideally support closures natively using V's anonymous functions (e.g., `return fn (n int) int { return n * factor }`). If this isn't supported, it should raise a clear translation warning or error rather than generating invalid module-level functions.

**Output from V compiler:**
```
test_advanced.v:34:16: error: undefined ident: `factor`
   32 | }
   33 | pub fn multiplier(n int) int {
   34 |     return n * factor
      |                ~~~~~~
   35 | }

test_advanced.v:47:15: error: assignment mismatch: 1 variable but `create_multiplier()` returns 0 values
   45 |     data << 4
   46 |     processed := process_numbers(data)
   47 |     times_two := create_multiplier(2)
      |               ~~
```

### 3. Collection Types with Unions (e.g., `list[int | str]`)
**Description:**
As seen in previous tests, inline sum types like `[]int | string` are generated for collections, which are invalid in modern V. Even when manually correcting this to a standard type (e.g., `[]Any`), V strictly forbids appending mixed types without explicit boxing/casting to an interface or a properly defined sum type. The generated V code uses `data << 1` and `data << '2'` on the array, which immediately throws type append errors.

**Expected Behavior:**
The transpiler should define a named sum type for the array (e.g. `type IntOrString = int | string`), type the array as `[]IntOrString`, and correctly cast or wrap elements as they are appended to the list (e.g., `data << IntOrString(1)`).

**Output from V compiler:**
```
test_advanced.v:5:31: error: inline sum types have been deprecated and will be removed on January 1, 2023 due to complicating the language and the compiler too much; define named sum types with `type Foo = Bar | Baz` instead
    3 | import div72.vexc
    4 |
    5 | pub fn process_numbers(nums []int | string) []int {
      |                               ~~~

test_advanced.v:43:13: error: cannot append `string` to `[]Any`
   41 |     mut data := []Any{cap: 4}
   42 |     data << 1
   43 |     data << '2'
      |             ~~~
```