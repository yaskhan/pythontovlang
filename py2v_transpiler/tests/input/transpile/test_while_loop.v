module main

// @line: test_while_loop.py:1:0
pub fn test_while_basic() {
    mut i := 0
    for i < 5 {
        println('i=${i}')
        i += 1
    }
}
// @line: test_while_loop.py:7:0
pub fn test_while_with_condition() {
    nums := [1, 2, 3, 4, 5]
    mut i := 0
    for i < nums.len {
        println('nums[${i}]=${nums[i]}')
        i += 1
    }
}
// @line: test_while_loop.py:14:0
pub fn test_while_break() {
    mut i := 0
    for i < 10 {
        if i == 5 {
            break
        }
        println('i=${i}')
        i += 1
    }
}
// @line: test_while_loop.py:22:0
pub fn test_while_continue() {
    mut i := 0
    for i < 5 {
        i += 1
        if i == 3 {
            continue
        }
        println('i=${i}')
    }
}
// @line: test_while_loop.py:30:0
pub fn test_while_else() {
    mut i := 0
    mut py_loop_completed_0 := true
    for i < 3 {
        println('i=${i}')
        i += 1
    }
    if py_loop_completed_0 {
        println('While loop completed normally')
    }
}
// @line: test_while_loop.py:38:0
pub fn test_while_else_break() {
    mut i := 0
    mut py_loop_completed_1 := true
    for i < 3 {
        if i == 2 {
            py_loop_completed_1 = false
            break
        }
        println('i=${i}')
        i += 1
    }
    if py_loop_completed_1 {
        println('This won\'t print (break)')
    }
}
// @line: test_while_loop.py:48:0
pub fn test_while_infinite() {
    mut count := 0
    for true {
        if count >= 3 {
            break
        }
        println('count=${count}')
        count += 1
    }
}
// @line: test_while_loop.py:57:0
pub fn test_while_nested() {
    mut i := 0
    for i < 3 {
        mut j := 0
        for j < 3 {
            print('(${i}, ${j}) ')
            j += 1
        }
        println('')
        i += 1
    }
}
// @line: test_while_loop.py:67:0
pub fn test_while_decrement() {
    mut i := 5
    for i > 0 {
        println('i=${i}')
        i -= 1
    }
}
// @line: test_while_loop.py:73:0
pub fn test_while_multiple_conditions() {
    a, b := 0, 10
    for a < 5 && b > 5 {
        println('a=${a}, b=${b}')
        a += 1
        b -= 1
    }
}
// @line: test_while_loop.py:80:0
pub fn test() {
    test_while_basic()
    test_while_with_condition()
    test_while_break()
    test_while_continue()
    test_while_else()
    test_while_else_break()
    test_while_infinite()
    test_while_nested()
    test_while_decrement()
    test_while_multiple_conditions()
}

fn main() {
    // @line: test_while_loop.py:92:0
    // if __name__ == '__main__':
    test()
}