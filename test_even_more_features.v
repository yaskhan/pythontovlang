module main

pub struct MathUtils {
}
pub struct User {
    _first string
    _last string
}
type SumType_IntString = int | string

// @staticmethod
pub fn add(a int, b int) int {
    return a + b
}
// @classmethod
pub fn create(cls int, val int) {
    println('Creating from class method: ${val}')
    return val
}
pub fn new_user(first string, last string) User {
    mut self := User{}
    self._first = first
    self._last = last
    return self
}
// @property
pub fn (self User) full_name() string {
    return '${self._first} ${self._last}'
}
// @full_name__setter
pub fn (self User) set_full_name(value string) {
    parts := value.split(' ')
    if len(parts) == 2 {
        self._first = parts[0]
        self._last = parts[1]
    }
}
pub fn match_status(status SumType_IntString) {
    // Match statement converted to separate if blocks
    _match_subject_1 := status
    _match_subject_any_1 := Any(_match_subject_1)
    mut _match_found_1 := false
    if !_match_found_1 && (_match_subject_any_1 == 200) {
        println('OK')
        _match_found_1 = true
    }
    if !_match_found_1 && (_match_subject_any_1 == 404) {
        println('Not Found')
        _match_found_1 = true
    }
    if !_match_found_1 && (_match_subject_any_1 == 'error') {
        println('Server Error')
        _match_found_1 = true
    }
    if !_match_found_1 {
        println('Unknown')
        _match_found_1 = true
    }
}
pub fn test() {
    println('${MathUtils.add(1, 2)}')
    MathUtils.create(10)
    u := new_user('John', 'Doe')
    println('${u.full_name}')
    u.full_name = 'Jane Smith'
    println('${u.full_name}')
    match_status(200)
    match_status('error')
    match_status(500)
}

fn main() {
    // if __name__ == '__main__':
    test()
}