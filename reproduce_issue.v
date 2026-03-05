module main

pub struct User {
    py_first string
    py_last string
}

pub fn new_user(first string, last string) User {
    mut self := User{}
    self.py_first = first
    self.py_last = last
    return self
}
pub fn test_underscore_vars() {
    py_local_var := 10
    println('${py_local_var}')
}
pub fn test_match_underscore(status int) {
    // Match statement converted to separate if blocks
    match_subject_1 := status
    match_subject_any_1 := Any(match_subject_1)
    mut match_found_1 := false
    if !match_found_1 && (match_subject_any_1 == 200) {
        return 'OK'
        match_found_1 = true
    }
    if !match_found_1 {
        return 'Unknown'
        match_found_1 = true
    }
}
