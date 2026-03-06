# Py2V Transpiler Sys, Math, and String Method Issues

The following issues were identified while transpiling Python code testing `sys`, `math`, `os.environ`, and common string methods. Note that basic `sys` attribute mapping (`sys.argv` -> `os.args`, `sys.platform` -> `os.user_os()`) and single-argument `math` functions worked seamlessly!

### 1. `math.log` Argument Mismatch
**Description:**
In Python, `math.log(x, base)` accepts an optional second argument for the logarithmic base. When the transpiler encounters this, it translates it directly to V's `math.log(10, 2)`. However, V's `math.log(x)` only calculates the natural logarithm and accepts exactly one argument.

**Expected Behavior:**
The transpiler should map `math.log(x, base)` to a custom helper calculation or directly to `math.log(x) / math.log(base)` if a second argument is provided. Furthermore, it should ideally cast integer literals to `f64` since `math.log` expects an `f64`.

**Output from V compiler:**
```
test_system_and_math.v:17:29: error: expected 1 argument, but got 2
   15 |     sin_val := math.sin(val)
   16 |     factorial := math.factorial(5)
   17 |     log_val := math.log(10, 2)
      |                             ^
```

### 2. `os.environ.get()` Method Visibility
**Description:**
The transpiler correctly maps `os.environ` to V's `os.environ()` which returns a `map[string]string`. However, the code then attempts to call `.get('KEY', 'default')` on this map. In V, `.get()` is a private method for maps and is not meant to be called directly in this manner.

**Expected Behavior:**
The transpiler should translate dictionary `.get(key, default)` operations into V's `or` fallback syntax (e.g., `os.environ()['MY_TEST_VAR'] or { 'default' }`) rather than calling `.get()`. (Note: The transpiler *does* do this for standard dictionaries, but it seems to fail to identify `os.environ()` as a map when parsing the AST, so it defaults to direct method translation).

**Output from V compiler:**
```
test_system_and_math.v:21:28: error: method `map[string]string.get` is private
   19 | }
   20 | pub fn test_os_environ() {
   21 |     my_env := os.environ().get('MY_TEST_VAR', 'default')
      |                            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

### 3. String Methods (`splitlines` and `join`) Mismatches
**Description:**
Python has built-in string methods like `.splitlines()` and `sep.join(list)`. The transpiler maps these directly without translation (`string.splitlines()` and `string.join()`). However, these methods do not exist natively on V strings in this exact form. V uses `.split_into_lines()` instead of `.splitlines()`, and array joining is done via `array.join(sep)` rather than `sep.join(array)`.

**Expected Behavior:**
- `.splitlines()` should be mapped to `.split_into_lines()`.
- `sep.join(array)` should be transformed to `array.join(sep)`.

**Output from V compiler:**
```
test_system_and_math.v:29:20: error: unknown method or field: `string.splitlines`.
Did you mean `split_into_lines`?
   28 | Line 3'
   29 |     split := lines.splitlines()
      |                    ~~~~~~~~~~~~

test_system_and_math.v:30:21: error: unknown method or field: `string.join`
   29 |     split := lines.splitlines()
   30 |     joined := ' - '.join(split)
      |                     ~~~~~~~~~~~
```