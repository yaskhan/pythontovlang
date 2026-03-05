module main

import div72.vexc

// Pydantic Model: User
@[params]
pub struct User {
pub mut:
    name string
    email string
}

// @pydantic.field_validator('email')
// @classmethod
pub fn User_validate_email(v string) string {
    if '@' !in v {
        vexc.raise('ValueError', 'Invalid email')
    }
    return v.lower()
}
// @pydantic.computed_field
// @property
pub fn (self User) display_name() string {
    return '${self.name} <${self.email}>'
}
