module main

// @line: reproduce_issue.py:1:0
pub struct User {
    _first string
}

// @line: reproduce_issue.py:2:4
pub fn new_user(_first string) User {
    mut self := User{}
    self._first = _first
    return self
}
// @line: reproduce_issue.py:5:0
pub fn test_match() {
    status := 200
    // Match statement converted to separate if blocks
    py_match_subject_1 := status
    py_match_subject_any_1 := (py_match_subject_1 as Any)
    mut py_match_found_1 := false
    if !py_match_found_1 && (py_match_subject_any_1 == 200) {
        _match_subject_1 := 'ok'
        println('${_match_subject_1}')
        py_match_found_1 = true
    }
}
