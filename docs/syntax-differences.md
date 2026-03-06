# Python Syntax Differences and Forward Compatibility

This document describes how the transpiler handles differences between Python versions and ensures forward compatibility with future Python syntax (e.g., Python 3.14+).

## Forward Compatibility Infrastructure

The transpiler includes a dedicated `CompatibilityLayer` (`py2v_transpiler/core/compatibility.py`) that handles:

1.  **Soft Keywords**: Keywords that are only reserved in certain contexts (like `match` and `case` in Python 3.10+). The transpiler identifies these to avoid naming collisions when they are used as identifiers in older code or when they collide with V reserved keywords.
2.  **Source Pre-processing**: A pipeline that transforms newer Python syntax into a form that the current Python `ast` module can parse. This allows the transpiler to support features from newer Python versions even when running on an older Python interpreter.

## Supported Future Syntax (Python 3.14+)

### PEP 758: Bracketless Except Blocks

Python 3.14 introduces support for bracketless multi-exception clauses in `except` and `except*` blocks.

**Python 3.14 Syntax:**
```python
try:
    ...
except ValueError, TypeError as e:
    ...
```

**Transpiler Handling:**
The `CompatibilityLayer` automatically wraps these exceptions in parentheses during pre-processing:
```python
except (ValueError, TypeError) as e:
```
This allows the standard `ast.parse()` to handle the code regardless of the Python version running the transpiler.

## Soft Keywords

The following Python soft keywords are tracked and handled:
- `match`
- `case`
- `type` (as in `type T = int`)
- `soft` (reserved for future use)

If these are used as identifiers in Python code, the transpiler ensures they do not conflict with V's own reserved keywords by applying sanitization (e.g., prefixing with `py_`).

## Adding Support for New Syntax

## Constructor Naming Convention

The transpiler handles Python constructors (`__init__`) and instance creators (`__new__`) by mapping them to V factory functions or methods.

### Factory Functions

By default, the `__init__` method is transpiled to a factory function named `new_ClassName`. This matches V's common pattern for object creation.

**Python:**
```python
class Point:
    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y
```

**Generated V:**
```v
fn new_Point(x int, y int) Point {
    mut self := Point{}
    self.x = x
    self.y = y
    return self
}
```

### Classes with `__new__`

If a class defines `__new__`, it becomes the primary factory function `new_ClassName`. If `__init__` is also present, it is transpiled to a regular method named `init` which is called (manually or implicitly) on the instance.

**Python:**
```python
class Decimal:
    def __new__(cls, value: str) -> "Decimal":
        return object.__new__(cls)

    def __init__(self, value: str):
        self.value = value
```

**Generated V:**
```v
fn new_Decimal(value string) Decimal {
    return Decimal{}
}

fn (mut self Decimal) init(value string) {
    self.value = value
}
```

This prevents the redundant `new_ClassName_new` naming pattern and ensures idiomatic V constructors.

To add support for a new Python syntax change:

1.  Open `py2v_transpiler/core/compatibility.py`.
2.  Add a new pre-processing method (e.g., `_preprocess_new_feature`).
3.  Implement the transformation using regular expressions or string manipulation to convert the new syntax into an older, equivalent syntax.
4.  Register the new method in `preprocess_source`.
5.  If the change introduces new soft keywords, add them to the `PYTHON_SOFT_KEYWORDS` set.
