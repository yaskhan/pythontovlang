module main

// @line: test_if_statement.py:1:0
pub fn test_if_basic() {
    mut x := 10
    if x > 5 {
        println('${x} > 5')
    }
}
// @line: test_if_statement.py:6:0
pub fn test_if_else() {
    mut x := 3
    if x > 5 {
        println('${x} > 5')
    } else {
        println('${x} <= 5')
    }
}
// @line: test_if_statement.py:13:0
pub fn test_if_elif_else() {
    mut x := 5
    if x > 10 {
        println('${x} > 10')
    } else if x > 5 {
        println('${x} > 5')
    } else if x == 5 {
        println('${x} == 5')
    } else {
        println('${x} < 5')
    }
}
// @line: test_if_statement.py:24:0
pub fn test_if_nested() {
    mut x := 10
    mut y := 20
    if x > 5 {
        if y > 15 {
            println('x > 5 and y > 15')
        }
    }
}
// @line: test_if_statement.py:31:0
pub fn test_if_and_condition() {
    mut x := 10
    mut y := 20
    if x > 5 && y > 15 {
        println('Both conditions true')
    }
}
// @line: test_if_statement.py:37:0
pub fn test_if_or_condition() {
    mut x := 3
    mut y := 10
    if x > 5 || y > 5 {
        println('At least one condition true')
    }
}
// @line: test_if_statement.py:43:0
pub fn test_if_not() {
    mut x := false
    if !x {
        println('x is False')
    }
}
// @line: test_if_statement.py:48:0
pub fn test_if_in() {
    lst := [1, 2, 3, 4, 5]
    if 3 in lst {
        println('3 is in the list')
    }
}
// @line: test_if_statement.py:53:0
pub fn test_if_is() {
    mut x := ?bool(none)
    if x == none {
        println('x is None')
    }
}
// @line: test_if_statement.py:58:0
pub fn test_if_ternary() {
    mut x := 10
    result := if x > 0 { 'positive' } else { 'non-positive' }
    println('x is ${result}')
}
// @line: test_if_statement.py:63:0
pub fn test_if_multiple_elif() {
    score := 85
    mut grade := ?int(none)
    if score >= 90 {
        grade = 'A'
    } else if score >= 80 {
        grade = 'B'
    } else if score >= 70 {
        grade = 'C'
    } else if score >= 60 {
        grade = 'D'
    } else {
        grade = 'F'
    }
    println('Grade: ${grade}')
}
// @line: test_if_statement.py:77:0
pub fn test_if_truthy() {
    value := 'hello'
    if value.len > 0 {
        println('Truthy value: ${value}')
    }
    empty := ''
    if empty.len == 0 {
        println('Empty string is falsy')
    }
}
// @line: test_if_statement.py:86:0
pub fn test_if_comparison_chain() {
    mut x := 5
    if (0 < x) && (x < 10) {
        println('${x} is between 0 and 10')
    }
}
// @line: test_if_statement.py:91:0
pub fn test() {
    test_if_basic()
    test_if_else()
    test_if_elif_else()
    test_if_nested()
    test_if_and_condition()
    test_if_or_condition()
    test_if_not()
    test_if_in()
    test_if_is()
    test_if_ternary()
    test_if_multiple_elif()
    test_if_truthy()
    test_if_comparison_chain()
}

fn main() {
    // @line: test_if_statement.py:106:0
    // if __name__ == '__main__':
    test()
}