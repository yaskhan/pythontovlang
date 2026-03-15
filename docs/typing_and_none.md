# Handling Dynamic Types, `None`, and Boolean Operators

The Python to V transpiler navigates strict differences between Python's highly dynamic typing system and V's statically typed constraints. This document details how the transpiler maps fundamental dynamic patterns—specifically the `Any` type, the `None` singleton, and dynamic boolean evaluation.

---

## 1. The `Any` Type and `NoneType`

Python frequently utilizes the `typing.Any` type to denote variables that can hold absolutely anything, and heavily utilizes `None` to represent empty states.

In older versions of the transpiler, `Any` was defined as an optional sum type (e.g. `?AnyValue` or `type Any = ... | none`). However, modern V compilers prohibit creating aliases for Option (`?`) types and explicitly forbid including the `none` keyword directly inside a sum type declaration.

To solve this while retaining perfect compatibility with Python's dynamic lists and dictionaries, the transpiler generates a custom `NoneType` struct that acts as Python's `None` within the `Any` universe:

```v
// Generated inside V helpers
pub struct NoneType {}

pub fn (n NoneType) str() string {
    return 'None'
}

pub type Any = NoneType | []Any | []u8 | bool | f64 | i64 | int | map[string]Any | string
```

### Assignments and Initializations

When translating untyped variables or variables explicitly typed as `Any`, assigning `None` compiles to wrapping the custom `NoneType` structure in the `Any` sum type:

**Python:**
```python
x: Any = None
```

**Transpiled V:**
```v
mut x := Any(NoneType{})
```

If a variable is known to be a strict Python `Optional[T]`, the transpiler leverages V's native optional syntax (`?T`) and continues to use the native `none` keyword safely.

---

## 2. Comparing `None`

Because `None` maps to `NoneType{}` in dynamic contexts, standard equality checks must be carefully translated to pass V's strict type checker.

* **For Sum Types (`Any`):** V does not allow you to compare a complex sum type directly to the `none` literal via `== none`. Instead, you use the `is` operator to check the active variant of the sum type. The transpiler detects if the variable being compared is typed as `Any` (or `unknown`) and converts `x is None` and `x == None` to `x is NoneType`.
* **For Option Types (`?T`):** If the transpiler has successfully inferred the type as optional, it continues generating `x == none` and `x != none`.

**Python:**
```python
if x is None:
    print("Empty")
```

**Transpiled V:**
```v
if x is NoneType {
    println('Empty')
}
```

---

## 3. Dynamic Boolean Operators (`and` / `or`)

In Python, the logical operators `and` and `or` do *not* strictly return boolean values. They are short-circuiting operators that evaluate and return the underlying objects based on truthiness:
* `'value' or 'default'` returns `'value'`
* `None or 'default'` returns `'default'`

V’s `&&` and `||` operators are strictly typed—they require both operands to be `bool` and strictly evaluate to a `bool`. Trying to write `value || 'default'` in V results in a compilation error.

### Safe Translation Strategy

The transpiler handles `ast.BoolOp` by explicitly evaluating whether the operands are purely boolean.
* **If all operands are inferred as `bool`:** It emits V's standard `&&` and `||`.
* **If operands are dynamic types (like `Any` or `str`):** It generates a short-circuiting, nested `if`-expression tree. It also uses a helper function (`py_bool`) to correctly determine the Python-like truthiness of the variable.
* **Type Unification:** Since V `if`-expressions must return the same type from all branches, the transpiler checks the inferred return types of all branches. If they differ, it explicitly casts all returned branches to `Any`.

**Python:**
```python
result = value or "default"
```

**Transpiled V:**
```v
mut result := if py_bool(value) { value } else { Any('default') }
```

This guarantees safety during V compilation while perfectly matching Python's dynamic run-time behavior.

---

## 4. PEP 695 Variance Modifiers

Python 3.13 introduced variance modifiers for PEP 695 type parameters: `+T` (covariant) and `-T` (contravariant).

**Python:**
```python
class Container[+T]:
    pass
```

### V Translation

V generics currently do not explicitly support variance modifiers. The transpiler detects these modifiers and preserves them as comments in the generated V code to ensure future-proofing and maintain metadata.

**Transpiled V:**
```v
struct Container[T /* + */] {
}
```

Correct variance is enforced during the transpilation process by Mypy (version 1.12+). If Mypy reports a variance violation, the transpiler will surface this error to the user.

---

## 5. PEP 696 Generic Defaults

Python 3.13+ introduced support for default values in generic type parameters (PEP 696).

**Python:**
```python
class Box[T = int]:
    def __init__(self, val: T):
        self.val = val

def foo[T = str](x: T) -> T:
    return x
```

### V Translation

V does not currently support default type parameters for generics. The transpiler detects PEP 696 defaults and preserves them as comments in the generated V code (e.g., `[T /* = int */]`). This maintains documentation and metadata while ensuring the code remains valid V.

**Transpiled V:**
```v
struct Box[T /* = int */] {
    val T
}

fn foo[T /* = string */](x T) T {
    return x
}
```

At call sites or instantiation points where Python would omit the type and rely on the default, the transpiler relies on Mypy's static analysis to infer and inject the appropriate explicit type parameters (e.g., `Box[int]{...}`), satisfying V's requirement for concrete types.