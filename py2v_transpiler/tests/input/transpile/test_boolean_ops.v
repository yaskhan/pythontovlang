module main

// @line: test_boolean_ops.py:1:0
pub fn test_boolean_and() {
    mut a := true
    mut b := false
    println('True and False = ${if a != 0 { b } else { a }}')
    println('True and True = ${true && true}')
    println('False and anything = ${if false { Any("something") } else { Any(false) }}')
}
// @line: test_boolean_ops.py:8:0
pub fn test_boolean_or() {
    mut a := true
    mut b := false
    println('True or False = ${if a != 0 { a } else { b }}')
    println('False or False = ${false || false}')
    println('True or anything = ${if true { Any(true) } else { Any("something") }}')
}
// @line: test_boolean_ops.py:15:0
pub fn test_boolean_not() {
    println('not True = ${!true}')
    println('not False = ${!false}')
}
// @line: test_boolean_ops.py:19:0
pub fn test_boolean_short_circuit_and() {
// @line: test_boolean_ops.py:20:4
    mut should_not_run := fn () int {
        println('This should not print')
        return true
    }
    mut result := if false { Any(should_not_run()) } else { Any(false) }
    println('Result: ${result}')
}
// @line: test_boolean_ops.py:28:0
pub fn test_boolean_short_circuit_or() {
// @line: test_boolean_ops.py:29:4
    mut should_not_run := fn () int {
        println('This should not print')
        return false
    }
    mut result := if true { Any(true) } else { Any(should_not_run()) }
    println('Result: ${result}')
}
// @line: test_boolean_ops.py:37:0
pub fn test_boolean_chaining() {
    x := 5
    mut result := (0 < x) && (x < 10)
    println('0 < ${x} < 10 = ${result}')
    result = (0 < x) && (x < 3)
    println('0 < ${x} < 3 = ${result}')
}
// @line: test_boolean_ops.py:45:0
pub fn test_boolean_with_values() {
    println('bool(0) = ${(0 != 0)}')
    println('bool(1) = ${(1 != 0)}')
    println('bool(\'\') = ${("" != '')}')
    println('bool(\'hello\') = ${("hello" != '')}')
    println('bool([]) = ${([]Any{}.len > 0)}')
    println('bool([1, 2]) = ${([1, 2].len > 0)}')
    println('bool(None) = ${py_bool(none)}')
}
// @line: test_boolean_ops.py:55:0
pub fn test_boolean_or_default() {
    mut name := ''
    mut result := if name.len > 0 { name } else { 'Anonymous' }
    println('Default name: ${result}')
    name = 'Alice'
    result = if name.len > 0 { name } else { 'Anonymous' }
    println('Actual name: ${result}')
}
// @line: test_boolean_ops.py:65:0
pub fn test_boolean_and_conditional() {
    mut enabled := true
    mut result := if enabled != 0 { Any('Feature is enabled') } else { Any(enabled) }
    println('Status: ${result}')
    enabled = false
    result = if enabled != 0 { Any('Feature is enabled') } else { Any(enabled) }
    println('Status: ${result}')
}
// @line: test_boolean_ops.py:75:0
pub fn test_boolean_comparison() {
    mut a := 10
    mut b := 20
    println('a == b: ${a == b}')
    println('a != b: ${a != b}')
    println('a < b: ${a < b}')
    println('a > b: ${a > b}')
    println('a <= b: ${a <= b}')
    println('a >= b: ${a >= b}')
}
// @line: test_boolean_ops.py:86:0
pub fn test_boolean_identity() {
    mut a := [1, 2, 3]
    mut b := [1, 2, 3]
    c := a
    println('a == b: ${a == b}')
    println('a is b: ${a == b}')
    println('a is c: ${a == c}')
    println('a is not b: ${a != b}')
    println('a is not c: ${a != c}')
}
// @line: test_boolean_ops.py:98:0
pub fn test_boolean_in() {
    lst := [1, 2, 3, 4, 5]
    println('3 in list: ${3 in lst}')
    println('10 in list: ${10 in lst}')
    println('10 not in list: ${10 !in lst}')
}
// @line: test_boolean_ops.py:104:0
pub fn test() {
    test_boolean_and()
    test_boolean_or()
    test_boolean_not()
    test_boolean_short_circuit_and()
    test_boolean_short_circuit_or()
    test_boolean_chaining()
    test_boolean_with_values()
    test_boolean_or_default()
    test_boolean_and_conditional()
    test_boolean_comparison()
    test_boolean_identity()
    test_boolean_in()
}

fn main() {
    // @line: test_boolean_ops.py:118:0
    // if __name__ == '__main__':
    test()
}