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

To add support for a new Python syntax change:

1.  Open `py2v_transpiler/core/compatibility.py`.
2.  Add a new pre-processing method (e.g., `_preprocess_new_feature`).
3.  Implement the transformation using regular expressions or string manipulation to convert the new syntax into an older, equivalent syntax.
4.  Register the new method in `preprocess_source`.
5.  If the change introduces new soft keywords, add them to the `PYTHON_SOFT_KEYWORDS` set.
