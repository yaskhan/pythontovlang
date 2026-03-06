# Pydantic Support

The transpiler includes dedicated support for transpiling [Pydantic](https://docs.pydantic.dev/) models into native Vlang structs with automatic validation.

## Supported Features

- **`BaseModel` Inheritance**: Python classes inheriting from `pydantic.BaseModel` are automatically detected and converted into Vlang structs.
- **Field Detection**: Type annotations for class attributes are correctly mapped to their Vlang equivalents (e.g., `Optional[int]` to `?int`).
- **`pydantic.Field` arguments**:
    - `alias="..."`: Translates into Vlang `[json: '...']` tags on the struct field.
    - `default=...`: Sets the default value of the Vlang struct attribute.
    - **Validation constraints** (`gt`, `lt`, `ge`, `le`, `max_length`, `min_length`): Generates a custom `.validate() !` method on the Vlang struct.
- **Validators** (`@validator`, `@field_validator`, `@model_validator`): Detected by the transpiler. Currently passed through to the standard code generation, but serves as a hook for advanced manual implementation.
- **Nested `Config` class**: Supports model-wide configuration options.

### Supported Config Options

| Option | Vlang Implementation |
|--------|----------------------|
| `str_strip_whitespace` | Calls `.trim()` on all string fields in `.validate()` |
| `str_to_lower` | Calls `.to_lower()` on all string fields in `.validate()` |
| `str_to_upper` | Calls `.to_upper()` on all string fields in `.validate()` |
| `min_anystr_length` | Adds length check to all string fields in `.validate()` |
| `max_anystr_length` | Adds length check to all string fields in `.validate()` |
| `validate_all` | Ensures `.validate()` method is always generated |
| `allow_mutation` | If `False`, removes `mut` keyword from V struct fields |
| `extra` | Emits a comment; V structs are strict by default (`forbid`) |
| `validate_assignment` | Emits a comment; currently not enforced on every assignment |

## How it works (Architecture)

To keep the core transpiler clean, Pydantic support is strictly isolated in the `py2v_transpiler/pydantic_support/` directory:

- **`PydanticDetector`**: Analyzes the AST to identify `BaseModel` classes, `Field()` assignments, and validator decorators.
- **`PydanticModelProcessor`**: Replaces the standard class generator when a Pydantic model is found. It constructs the V struct, adds `[json]` tags, default values, and automatically generates the `.validate() !` method.
- **`PydanticFieldProcessor`**: Extracts arguments from `pydantic.Field(...)` calls to build validation conditions and tags.

When the core AST visitors (`ClassesMixin` and `AnnotationsMixin`) encounter these patterns, they delegate the execution to the processors above.

## Example

### Python Code

```python
from pydantic import BaseModel, Field

class User(BaseModel):
    id: int
    name: str = Field(alias='userName', max_length=50)
    age: int = Field(gt=0, default=18)
```

### Transpiled Vlang Code

```v
// Pydantic Model: User
@[params]
pub struct User {
pub mut:
    id int
    name string [json: 'userName']
    age int = 18
}

pub fn (mut m User) validate() ! {
    if m.name.len > 50 { return error('Validation Error: name length must be <= 50') }
    if m.age <= 0 { return error('Validation Error: age must be greater than 0') }
}
```
