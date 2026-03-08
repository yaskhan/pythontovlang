# LLM Comments for Code Review

The Python → V transpiler automatically inserts special `//##LLM@@` comments into the generated V code. These comments help developers and AI assistants quickly identify places that require manual refinement due to fundamental differences between Python and V.

## Comment Format

All LLM comments start with the `//##LLM@@` prefix and contain:
- A description of the Python code problem or feature
- Recommendations for manual refinement in V
- Code examples or temporary solutions when necessary

**Example:**
```v
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
pub fn wrapper(args ...Any, kwargs map[string]Any) {
    // ...
}
```

## LLM Comment Categories

### 1. Functions and Parameters

| Situation | Comment |
|-----------|---------|
| Function with both `*args` and `**kwargs` | Requires parameter reordering (variadic must be last) |
| Unusual function name after transliteration | Recommended to simplify the name |
| Overloaded functions | Recommended to consolidate or simplify names |
| `global`/`nonlocal` in functions | V does not directly support global state |
| Unmapped dunder methods | Requires manual behavior implementation |

**Python Example:**
```python
def wrapper(*args, **kwargs):
    pass
```

**Generated V:**
```v
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
pub fn wrapper(args ...Any, kwargs map[string]Any) {
    // ...
}
```

### 2. Dynamic Operations

| Situation | Comment |
|-----------|---------|
| `getattr`/`setattr`/`hasattr` | V requires static field typing |
| `eval()`/`exec()`/`compile()` | Dynamic code execution is not supported in V |
| `del` for variables | V does not support deleting variables from scope |
| `del` for attributes | V does not support deleting struct attributes |

**Python Example:**
```python
value = getattr(obj, 'attr', None)
```

**Generated V:**
```v
//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.
value := $if obj.has_field('attr') { true } $else { false }
```

### 3. Exceptions and Error Handling

| Situation | Comment |
|-----------|---------|
| `try/except/finally` | V uses Result/Option types instead of exceptions |
| Bare `except:` | May catch unexpected V panic/error |
| `except*` (ExceptionGroup) | V does not support group exception handling |
| `continue` in `finally` | V `defer` cannot be used here |
| Bare `raise` outside exception block | V cannot re-raise without active error |

**Python Example:**
```python
try:
    risky_operation()
except:
    print("Error occurred")
```

**Generated V:**
```v
//##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
risky_operation() or {
    //##LLM@@ Bare 'except:' block detected. This is generally bad practice and may inadvertently catch unexpected V panics/errors. Please review and restrict the caught exception types if possible.
    println('Error occurred')
}
```

### 4. Loops and Iterations

| Situation | Comment |
|-----------|---------|
| `enumerate()` with single variable | Required to unpack index and value |
| Async comprehensions | Required to implement async iterator semantics |
| Complex nested comprehensions | Recommended to unfold into explicit loops |

**Python Example:**
```python
for item in enumerate(data):
    print(item)
```

**Generated V:**
```v
//##LLM@@ Enumerate used with a single target variable instead of unpacking. Please rewrite to unpack the index and value properly.
for item in py_enumerate(data) {
    println(item)
}
```

### 5. Types and Annotations

| Situation | Comment |
|-----------|---------|
| `LiteralString` with `input()` | Loss of LiteralString guarantee |
| `LiteralString` with non-literal value | Required to check security implications |
| Annotation processing failed | Required to manually specify type |
| Union types (sum types) | Recommended to give meaningful type name |

**Python Example:**
```python
from typing import LiteralString
s: LiteralString = input()
```

**Generated V:**
```v
//##LLM@@ LiteralString variable 's' receives value from input() (loss of guarantee). Please review the security implications.
mut s := io.read_line()
```

### 6. Comprehensions

| Situation | Comment |
|-----------|---------|
| List comprehension | Support missing, requires manual transpilation |
| Set comprehension | Support missing, requires manual transpilation |
| Dict comprehension | Support missing, requires manual transpilation |
| Generator expression | Support missing, requires manual transpilation |

**Python Example:**
```python
result = [x * 2 for x in data if x > 0]
```

**Generated V:**
```v
//##LLM@@ List comprehension support is missing in the transpiler. Please manually transpile this list comprehension.
result := []int{cap: data.len}
for x in data {
    if x > 0 {
        result << x * 2
    }
}
```

### 7. Standard Library

| Module | Comment |
|--------|---------|
| `struct` | Methods are stubbed, requires implementing packing/unpacking |
| `pickle` | Partial mapping to JSON, may not work for complex objects |
| `fractions` | Incomplete string parsing |
| `threading` | PyThread is a placeholder, requires using V `spawn` |
| `bytes` formatting | Stubbed, may be incorrect |

**Python Example:**
```python
import pickle
data = pickle.dumps(obj)
```

**Generated V:**
```v
//##LLM@@ Pickle operations are partially mapped to JSON serialization. This may not handle complex objects or exact pickle semantics. Please review and manually implement correct binary serialization if required.
data := json.encode(obj) or { panic(err) }
```

### 8. Pydantic

| Situation | Comment |
|-----------|---------|
| Generic models `BaseModel[T]` | Requires manual type annotation in V |
| `Field(default_factory=...)` | Required to manually initialize value |
| Nested model fields | Validation does not call `.validate()` on nested models |
| Validator with `mode='wrap'` | Required to refactor validation logic |
| `@computed_field` | Generated as regular method without caching |

**Python Example:**
```python
from pydantic import BaseModel, Field

class Config(BaseModel):
    items: list[str] = Field(default_factory=list)
```

**Generated V:**
```v
//##LLM@@ Pydantic Generic model (BaseModel[T]) detected in 'Config'. This requires manual type annotation and adjustments in V. Please review the generated struct.
pub struct Config {
    //##LLM@@ Pydantic 'Field(default_factory=...)' detected on field 'items'. This is not fully supported by the transpiler. Please manually initialize the default value in the V struct or factory.
    items []string
}
```

### 9. Destructuring and Unpacking

| Situation | Comment |
|-----------|---------|
| Unsupported destructuring target | Required to manually implement unpacking logic |

**Python Example:**
```python
a, *b, c = [1, 2, 3, 4, 5]
```

**Generated V:**
```v
//##LLM@@ Unsupported destructuring target: <class 'ast.Starred'>. Please manually implement this unpacking logic in V.
a := data[0]
b := data[1:-1]
c := data[-1]
```

## Automatic Comment Generation

The transpiler automatically inserts LLM comments in the following cases:

1. **Problematic Python construct detected** — e.g., `*args` + `**kwargs` simultaneously
2. **Mapping failed** — e.g., unknown standard library method
3. **Type information lost** — e.g., annotation not recognized
4. **Python semantics differ from V** — e.g., exception handling
5. **Dynamic operations** — e.g., `getattr`, `eval`
6. **Temporary solutions (stubs)** — e.g., `pickle` → JSON

## Searching for LLM Comments in Code

To quickly find all places requiring refinement, use:

```bash
# Search on Linux/macOS
grep -r "//##LLM@@" output/

# Search on Windows (PowerShell)
Select-String -Path "output/*.v" -Pattern "//##LLM@@"

# Count comments
grep -rc "//##LLM@@" output/ | awk -F: '{sum+=$2} END {print sum}'
```

## Code Refinement Recommendations

1. **Start with functions** — they often contain critical parameter issues
2. **Check error handling** — replace `try/except` with V Result/Option types
3. **Eliminate dynamic operations** — replace with static reflection or explicit fields
4. **Optimize names** — simplify long function names
5. **Check standard library** — replace stubs with full implementations

## Integration with AI Assistants

LLM comments are designed for use with AI assistants:

1. **Automatic search** — AI can quickly find all `//##LLM@@` comments
2. **Contextual information** — each comment contains enough context to understand the problem
3. **Fix recommendations** — comments include specific refinement steps

**Example AI prompt:**
```
Find all //##LLM@@ comments in this file and fix problems in priority order:
1. Functions with incorrect parameters
2. Error handling
3. Dynamic operations
```

## Extending Functionality

To add a new LLM comment type to the transpiler:

1. Open the corresponding file in `py2v_transpiler/core/translator/`
2. Find where the problematic construct is handled
3. Add comment generation before code generation:

```python
self.output.append(f"{self._indent()}//##LLM@@ Problem description. Fix recommendations.")
```

4. Add a test in `py2v_transpiler/tests/translator/` to verify comment generation

## Usage Statistics

As of March 2026, the transpiler implements **40+ unique LLM comment types**, covering:
- 15+ function problem categories
- 10+ type problem categories
- 8+ standard library problem categories
- 7+ error handling problem categories
