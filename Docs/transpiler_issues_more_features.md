# Py2V Transpiler More Features Issues

The following issues were identified while transpiling Python code containing features such as decorators, `*args`/`**kwargs`, and `async`/`await`.

### 1. Variadic Arguments Order (`*args` before `**kwargs`)
**Description:**
When a Python function accepts both `*args` and `**kwargs` (e.g., `def wrapper(*args, **kwargs)`), the transpiler maps this to V variadic arguments and a map: `pub fn wrapper(args ...int, kwargs map[string]string)`. However, V strictly requires the variadic parameter (e.g., `...int`) to be the **final** parameter in the function signature. This causes a compilation error.

**Expected Behavior:**
The transpiler should reorder the parameters so that `...int` is always the last argument in the generated V function signature, regardless of the order defined in Python (though Python also mandates `*args` before `**kwargs`).

**Output from V compiler:**
```
test_more_features.v:5:16: error: cannot use ...(variadic) with non-final parameter args
    3 | import asyncio
    4 |
    5 | pub fn wrapper(args ...int, kwargs map[string]string) {
      |                ~~~~
```

### 2. Broken Decorator Implementation and Missing Return Types
**Description:**
The transpiler does not properly apply or evaluate decorators. Instead of wrapping the original function, it simply comments out the decorator (e.g., `// @my_decorator`) and leaves the function definitions untouched. Additionally, the wrapper function inside the decorator `my_decorator` refers to `func` (which is passed to the outer function), but due to the same nested function hoisting bug identified in earlier tests, it loses lexical scoping and fails because `func` is an undefined identifier. Furthermore, the transpiler infers `func` as type `int` rather than a function type, and misses the return type for `greet` and `wrapper`, causing `unexpected argument` errors when trying to return values.

**Expected Behavior:**
The transpiler needs to translate decorators to V by actively wrapping the target function, generating a new wrapped function, or leveraging V's reflection/attribute capabilities if applicable. If not fully supported, it should issue a warning rather than generating invalid code.

**Output from V compiler:**
```
test_more_features.v:7:15: error: unknown function: func
    5 | pub fn wrapper(kwargs map[string]string, args ...int) {
    6 |     println('Before call')
    7 |     result := func(...args, kwargs)
      |               ~~~~~~~~~~~~~~~~~~~~~

test_more_features.v:17:12: error: unexpected argument, current function does not return anything
   15 | pub fn greet(name string) {
   16 |     println('Hello, ${name}!')
   17 |     return name
      |            ~~~~
```

### 3. Async/Await is Commented Out and Ignored
**Description:**
When compiling `async` and `await` keywords, the transpiler does not attempt to map them to V's coroutines, channels, or `spawn` syntax. Instead, it transpiles the function as a normal synchronous function, and replaces `await` with a comment `/* await */`. If the code uses Python's `asyncio` library (e.g., `import asyncio`), it emits an import for a non-existent V module `asyncio`, causing immediate module resolution failure.

**Expected Behavior:**
The transpiler should map Python `async def` and `await` to V's concurrency mechanisms (like `spawn` threads and waiting for channels, or thread handles), and should likely map `asyncio.sleep` to `time.sleep`. Leaving `await` as a comment breaks the semantic meaning of the code entirely.

**Output from V compiler:**
```
test_more_features.v:3:1: builder error: cannot import module "asyncio" (not found)
    1 | module main
    2 |
    3 | import asyncio
      | ~~~~~~~~~~~~~~
```