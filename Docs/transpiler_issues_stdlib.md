# Py2V Transpiler Standard Library Issues

The following issues were identified while transpiling Python code using standard libraries such as `json` and `datetime`, as well as set operations.

### 1. `json` Mixed Type Mapping and Empty `or {}` Blocks
**Description:**
When defining a mixed-type dictionary intended for JSON serialization (e.g., `{"name": "Alice", "age": 30, "is_active": True}`), V enforces strict map typing, causing compilation errors where it expects all values to be strings. Additionally, when using `json.loads`, the transpiler decodes it into a `map[string]string` and appends an empty `or {}` block. Modern V requires the `or {}` block to either panic, return, or provide a fallback value for the assignment, making an empty block invalid.

**Expected Behavior:**
The transpiler should map mixed-type dicts used for JSON serialization to V structs (or `Any` types, though `json` module doesn't natively parse into unions well). For `json.decode`, the `or {}` block must not be completely empty if it's part of an assignment expression (it should be `or { panic(err) }` or similar).

**Output from V compiler:**
```
test_stdlib_features.v:7:38: error: invalid map value: expected `string`, not `int literal`
    5 |
    6 | pub fn test_json() {
    7 |     data := {'name': 'Alice', 'age': 30, 'is_active': true}
      |                                      ~~

test_stdlib_features.v:10:56: error: expression requires a non empty `or {}` block
    8 |     json_str := json.encode(data)
    9 |     println('JSON: ${json_str}')
   10 |     parsed := json.decode(map[string]string, json_str) or {}
      |                                                        ~~~~~
```

### 2. `datetime` Module Resolution Failure
**Description:**
The transpiler translates `datetime.now()` to `datetime.datetime.now()` and maps `import datetime` to `import time`. However, it doesn't define or map the `datetime` struct or namespace properly, leaving `datetime` as an undefined identifier. V's `time` module uses `time.now()` instead.

**Expected Behavior:**
The transpiler should properly map Python's `datetime.datetime.now()` to V's `time.now()`, and `datetime(y, m, d...)` to V's `time.new(...)`.

**Output from V compiler:**
```
test_stdlib_features.v:14:12: error: undefined ident: `datetime`
   12 | }
   13 | pub fn test_datetime() {
   14 |     now := datetime.datetime.now()
      |            ~~~~~~~~
```

### 3. Set Operations Not Supported on Maps
**Description:**
Python sets (e.g., `{1, 2, 3}`) are translated by the transpiler into V maps with boolean values (e.g., `{1: true, 2: true, 3: true}`). This is a standard workaround since V does not have a built-in Set collection type. However, when performing set operations like Union (`|`), Intersection (`&`), and Difference (`-`), the transpiler just passes these operators directly to the V maps (`set_a | set_b`). V does not support bitwise/mathematical operators on maps.

**Expected Behavior:**
The transpiler must implement custom helper functions for set operations when mapping them to boolean maps, such as iterating through the keys to construct the union, intersection, or difference.

**Output from V compiler:**
```
test_stdlib_features.v:22:18: error: undefined operation `map[int]bool` | `map[int]bool`
   20 |     set_a := {1: true, 2: true, 3: true}
   21 |     set_b := {3: true, 4: true, 5: true}
   22 |     union_val := set_a | set_b
      |                  ~~~~~~~~~~~~~
```