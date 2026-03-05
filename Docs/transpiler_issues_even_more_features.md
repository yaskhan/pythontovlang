# Py2V Transpiler Additional Features Issues

The following issues were identified while transpiling Python code containing classes with static/class methods, properties, private fields, and match/case structures.

### 1. Variables and Fields Starting with Underscore
**Description:**
Python often uses underscores prefixing fields and variables to indicate they are private or internal (e.g., `_first`, `_last`, `_match_subject_1`). However, the V compiler enforces strict naming rules where struct field names and variable names cannot start with an underscore (`_`). The transpiler preserves these underscores, causing compilation errors.

**Expected Behavior:**
The transpiler should map Python's private naming convention (`_field`) to a valid V naming convention (e.g., stripping the leading underscore, potentially using V's module-level visibility rules to mark them as non-`pub`).

**Output from V compiler:**
```
test_even_more_features.v:6:5: error: field name `_first` cannot start with `_`
    4 | }
    5 | pub struct User {
    6 |     _first string
      |     ~~~~~~~~~~~~~

test_even_more_features.v:40:5: error: variable name `_match_subject_1` cannot start with `_`
   38 | pub fn match_status(status SumType_IntString) {
   39 |     // Match statement converted to separate if blocks
   40 |     _match_subject_1 := status
      |     ~~~~~~~~~~~~~~~~
```

### 2. Static and Class Methods
**Description:**
The transpiler translates `@staticmethod` and `@classmethod` decorated functions as standard global `pub fn` functions rather than attaching them to the struct's namespace. When the transpiled code later tries to call them using `ClassName.method()` (e.g., `MathUtils.add`), the V compiler fails because it looks for a module function or struct method rather than a namespace resolution.

**Expected Behavior:**
To mimic Python's static/class methods, the transpiler should likely generate them as global functions prefixed with the struct name (e.g., `MathUtils_add(a, b)`) and update call sites accordingly, or it should leverage module namespacing appropriately.

**Output from V compiler:**
```
test_even_more_features.v:61:16: error: unknown function: MathUtils.add
   59 | }
   60 | pub fn test() {
   61 |     println('${MathUtils.add(1, 2)}')
      |                ~~~~~~~~~~~~~~~~~~~
```

### 3. Property Mutability and Assignment
**Description:**
The transpiler partially translates `@property` and `@property.setter`. It creates getter and setter methods like `full_name()` and `set_full_name()`. However, two issues arise:
1) In `set_full_name`, the `self` parameter is immutable (`self User` instead of `mut self User`), causing an error when trying to modify fields inside the setter.
2) At the assignment call site (`u.full_name = "Jane Smith"`), the transpiler leaves the assignment as direct property access instead of converting it to a call to the generated setter method `u.set_full_name("Jane Smith")`.

**Expected Behavior:**
Property setters should automatically be given a `mut` receiver in V (`pub fn (mut self User) ...`). Additionally, assignments to a property should be compiled as calls to the associated `set_` method.

**Output from V compiler:**
```
test_even_more_features.v:34:9: error: `self` is immutable, declare it with `mut` to make it mutable
   32 |     parts := value.split(' ')
   33 |     if len(parts) == 2 {
   34 |         self._first = parts[0]
      |         ~~~~

test_even_more_features.v:65:19: error: cannot assign to `u.full_name`: expected `fn () string`, not `string`
   63 |     u := new_user('John', 'Doe')
   64 |     println('${u.full_name}')
   65 |     u.full_name = 'Jane Smith'
      |                   ~~~~~~~~~~~~
```

### 4. `match/case` Casting with Sum Types
**Description:**
When a `match` statement evaluates a union type variable (e.g., `SumType_IntString`), the transpiler attempts to cast it to V's `Any` type using a function-call syntax `Any(...)` instead of V's cast syntax (`x as Any` or type matching). This results in syntax/type errors where V rejects `Any` as an unknown type or function in this context, breaking the generated separate `if` blocks.

**Expected Behavior:**
The transpiler should properly use V's `match` statement combined with type assertions, or correctly use `as Any` if it must fall back to `Any`.

**Output from V compiler:**
```
test_even_more_features.v:41:29: error: unknown type `Any`.
   39 |     // Match statement converted to separate if blocks
   40 |     _match_subject_1 := status
   41 |     _match_subject_any_1 := Any(_match_subject_1)
      |                             ~~~~~~~~~~~~~~~~~~~~~
```