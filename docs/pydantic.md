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
- **Pydantic v2 Syntax**: Support for `ConfigDict`, `Annotated`, `field_validator`, `model_validator`, and `computed_field`.

### Supported Field Constraints

| Field Option | Vlang Implementation |
|--------------|----------------------|
| `alias` | `[json: 'alias']` struct tag |
| `default` | Default value in struct definition |
| `gt`, `lt`, `ge`, `le` | Comparison checks in `.validate()` |
| `max_length`, `min_length` | String/collection length checks |
| `pattern` / `regex` | `regex.match()` validation |
| `multiple_of` | Modulo operator check |
| `min_items`, `max_items` | Collection length checks |
| `unique_items` | Loop with map for uniqueness |
| `const` | Equality check |
| `description`, `title` | Struct tags |
| `exclude` | `[json: '-']` tag |

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

- **`PydanticDetector`**: Analyzes the AST to identify `BaseModel` classes, `Field()` assignments, validator decorators, and Config classes.
- **`PydanticModelProcessor`**: Replaces the standard class generator when a Pydantic model is found. It constructs the V struct, adds tags, default values, generates factory functions, and automatically generates the `.validate() !` method.
- **`PydanticFieldProcessor`**: Extracts arguments from `pydantic.Field(...)` calls to build validation conditions and tags. Supports `Annotated[T, Field(...)]` syntax.
- **`PydanticValidatorProcessor`**: Extracts validator metadata (fields, mode) for integration into `.validate()`.
- **`PydanticConfigProcessor`**: Processes nested `Config` class and `ConfigDict()` calls.

When the core AST visitors (`ClassesMixin` and `AnnotationsMixin`) encounter these patterns, they delegate the execution to the processors above.

## Example

### Python Code (Pydantic v1)

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

pub fn new_User(id int, age int, name string ...string) !User {
    mut self := User{
        id: id
        age: age
        name: if name.len > 0 { name[0] } else { '' }
    }
    self.validate() or { return err }
    return self
}

pub fn (mut m User) validate() ! {
    if m.name.len > 50 { return error("Validation Error: name length must be <= 50") }
    if m.age <= 0 { return error("Validation Error: age must be greater than 0") }
}
```

## Pydantic v2 Example

### Python Code (Pydantic v2)

```python
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Annotated

class User(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    name: Annotated[str, Field(min_length=2, max_length=50)]
    email: str

    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if '@' not in v:
            raise ValueError('Invalid email')
        return v.lower()
```

### Transpiled Vlang Code

```v
// Pydantic Model: User
// Config: str_strip_whitespace=true
@[params]
pub struct User {
pub mut:
    name string
    email string
}

pub fn new_User(name string, email string) !User {
    mut self := User{
        name: name
        email: email
    }
    self.validate() or { return err }
    return self
}

pub fn (mut m User) validate() ! {
    m.name = m.name.trim()
    m.email = m.email.trim()
    if m.name.len > 50 { return error("Validation Error: name length must be <= 50") }
    if m.name.len < 2 { return error("Validation Error: name length must be >= 2") }
    m.email = User_validate_email(m.email)
}

pub fn User_validate_email(v string) string {
    mut result := v
    if !strings.contains(result, '@') {
        panic('Invalid email')
    }
    result = result.to_lower()
    return result
}
```

## Known Limitations

1. **Validator mode='wrap'**: Not fully supported; validators are treated as 'before' or 'after'.
2. **`computed_field`**: Generated as a regular method; caching not implemented.
3. **Generic models**: `BaseModel[T]` requires manual type annotation.
4. **Nested models**: Flattened validation; no recursive `.validate()` calls.
5. **`Field(default_factory=...)`**: Not supported; use `default` instead.

## Testing

Run the Pydantic test suite:

```bash
python -m pytest py2v_transpiler/tests/translator/test_pydantic.py -v
python -m pytest py2v_transpiler/tests/translator/test_pydantic_v2.py -v
```
