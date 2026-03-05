module main

// Pydantic Model: User
@[params]
pub struct User {
pub mut:
    name string
    age int
    email string = 'unknown@example.com'
}

pub fn (mut m User) validate() ! {
    if m.name.len < 2 { return error('Validation Error: name length must be >= 2') }
    if m.age <= 0 { return error('Validation Error: age must be greater than 0') }
}
// new_user creates a new User and validates it.
pub fn new_user(name string, age int, email ...string) !User {
    mut self := User{
        name: name
        age: age
        email: if email.len > 0 { email[0] } else { 'unknown@example.com' }
    }
    self.validate() or { return err }
    return self
}
