module main

// @line: test_for_loop.py:1:0
pub fn test_for_basic() {
    for i in 0..5 {
        println('i=${i}')
    }
}
// @line: test_for_loop.py:5:0
pub fn test_for_list() {
    for item in [1, 2, 3, 4, 5] {
        println('item=${item}')
    }
}
// @line: test_for_loop.py:9:0
pub fn test_for_string() {
    for char_u8 in 'hello' {
        char := char_u8.ascii_str()
        println('char=${char}')
    }
}
// @line: test_for_loop.py:13:0
pub fn test_for_dict() {
    d := {'a': 1, 'b': 2, 'c': 3}
    println('Keys:')
    for key in d {
        println('key=${key}')
    }
    println('Values:')
    for value in d.values() {
        println('value=${value}')
    }
    println('Items:')
    for key, value in d {
        println('${key}=${value}')
    }
}
// @line: test_for_loop.py:28:0
pub fn test_for_break() {
    for i in 0..10 {
        if i == 5 {
            break
        }
        println('i=${i}')
    }
}
// @line: test_for_loop.py:34:0
pub fn test_for_continue() {
    for i in 0..5 {
        if i == 2 {
            continue
        }
        println('i=${i}')
    }
}
// @line: test_for_loop.py:40:0
pub fn test_for_else() {
    mut py_loop_completed_0 := true
    for i in 0..3 {
        println('i=${i}')
    }
    if py_loop_completed_0 {
        println('For loop completed normally')
    }
}
// @line: test_for_loop.py:46:0
pub fn test_for_else_break() {
    mut py_loop_completed_1 := true
    for i in 0..3 {
        if i == 2 {
            py_loop_completed_1 = false
            break
        }
        println('i=${i}')
    }
    if py_loop_completed_1 {
        println('This won\'t print (break)')
    }
}
// @line: test_for_loop.py:54:0
pub fn test_for_nested() {
    for i in 0..3 {
        for j in 0..3 {
            print('(${i}, ${j}) ')
        }
        println('')
    }
}
// @line: test_for_loop.py:60:0
pub fn test_for_enumerate() {
    items := ['a', 'b', 'c', 'd']
    for index, item in items {
        println('index=${index}, item=${item}')
    }
}
// @line: test_for_loop.py:65:0
pub fn test_for_zip() {
    names := ['Alice', 'Bob', 'Charlie']
    ages := [25, 30, 35]
    py_zip_it1_1 := names
    py_zip_it2_1 := ages
    for py_i_1, py_v1_1 in py_zip_it1_1 {
        if py_i_1 >= py_zip_it2_1.len { break }
        py_v2_1 := py_zip_it2_1[py_i_1]
        name := py_v1_1
        age := py_v2_1
        println('${name} is ${age}')
    }
}
// @line: test_for_loop.py:72:0
pub fn test_for_unpacking() {
    pairs := [[1, 2], [3, 4], [5, 6]]
    for py_val_139744124781328 in pairs {
        a := py_val_139744124781328[0]
        b := py_val_139744124781328[1]
        println('a=${a}, b=${b}')
    }
}
// @line: test_for_loop.py:77:0
pub fn test_for_else_found() {
    target := 5
    mut py_loop_completed_2 := true
    for i in 0..10 {
        if i == target {
            println('Found ${target}')
            py_loop_completed_2 = false
            break
        }
    }
    if py_loop_completed_2 {
        println('${target} not found')
    }
}
// @line: test_for_loop.py:87:0
pub fn test() {
    test_for_basic()
    test_for_list()
    test_for_string()
    test_for_dict()
    test_for_break()
    test_for_continue()
    test_for_else()
    test_for_else_break()
    test_for_nested()
    test_for_enumerate()
    test_for_zip()
    test_for_unpacking()
    test_for_else_found()
}

fn main() {
    // @line: test_for_loop.py:102:0
    // if __name__ == '__main__':
    test()
}