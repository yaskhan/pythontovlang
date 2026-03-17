# PEP 750: Template String Literals Format Spec Mapping

This document describes how Python template string (t-string) format specifiers and conversions are mapped to V when transpiled.

## Interpolation Structure

In V, the `Interpolation` struct is defined as:

```v
pub struct Interpolation {
pub:
    value       Any
    expression  string
    conversion  string // 'r', 's', 'a', or 'none'
    format_spec string
}
```

## Conversions

Python's conversion flags are mapped to strings:

| Python Flag | V `conversion` value | Description |
|-------------|----------------------|-------------|
| `!s`        | `'s'`                | `str()`     |
| `!r`        | `'r'`                | `repr()`    |
| `!a`        | `'a'`                | `ascii()`   |
| (none)      | `none`               | No conversion |

## Format Specifiers

The `format_spec` attribute in `Interpolation` contains the raw format specification string from the Python literal.

### Mapping Table

| Python Feature | Example | Transpiled V `format_spec` |
|----------------|---------|---------------------------|
| Width          | `{x:10}`| `'10'`                    |
| Precision      | `{x:.2f}`| `'.2f'`                  |
| Alignment      | `{x:<10}`| `'<10'`                   |
| Padding        | `{x:010}`| `'010'`                   |
| Complex specs  | `{x:*>10.2f}` | `'*>10.2f'`         |

### Dynamic Format Specifiers

Dynamic format specifiers (e.g., `t"{value:.{precision}f}"`) are eagerly evaluated during transpilation, matching Python's behavior for template strings. The resulting `format_spec` in V will be the evaluated string.

## Debug Specifier (`=`)

Python 3.13+ t-strings support the `=` debug specifier. Following PEP 750, `t"{value=}"` is transpiled as:

1.  The preceding string part is updated to include `value=`.
2.  The conversion is set to `'r'` (unless otherwise specified).
3.  The `expression` attribute is set to `'value'`.

Example: `t"Result: {a + b = :.2f}"`
- Preceding string: `"Result: a + b = "`
- Interpolation value: `a + b`
- Interpolation expression: `"a + b"`
- Interpolation conversion: `none` (because format spec is provided without conversion)
- Interpolation format spec: `".2f"`
