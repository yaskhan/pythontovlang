module main

// @line: test_range_type.py:1:0
pub fn test_range_basic() {
    mut r := py_range(5)
    println('range(5): ${[]Any(r)}')
    r = py_range(2, 7)
    println('range(2, 7): ${[]Any(r)}')
    r = py_range(0, 10, 2)
    println('range(0, 10, 2): ${[]Any(r)}')
}
// @line: test_range_type.py:11:0
pub fn test_range_negative() {
    mut r := py_range(-5, 0)
    println('range(-5, 0): ${[]Any(r)}')
    r = py_range(0, -5, -1)
    println('range(0, -5, -1): ${[]Any(r)}')
    r = py_range(5, -5, -2)
    println('range(5, -5, -2): ${[]Any(r)}')
}
// @line: test_range_type.py:21:0
pub fn test_range_iteration() {
    for i in 0..3 {
        println('i=${i}')
    }
}
// @line: test_range_type.py:25:0
pub fn test_range_indexing() {
    mut r := py_range(10, 20, 2)
    println('r[0]: ${r[0]}')
    println('r[2]: ${r[2]}')
    println('r[-1]: ${r[r.len - 1]}')
}
// @line: test_range_type.py:31:0
pub fn test_range_slicing() {
    mut r := py_range(10)
    mut sliced := []Any(r[2..6])
    println('r[2:6]: ${sliced}')
    sliced = []Any(py_list_slice(r, none, none, 3))
    println('r[::3]: ${sliced}')
}
// @line: test_range_type.py:39:0
pub fn test_range_len() {
    mut r := py_range(100, 200, 5)
    println('len(range(100, 200, 5)): ${r.len}')
}
// @line: test_range_type.py:43:0
pub fn test_range_membership() {
    mut r := py_range(0, 10, 2)
    println('4 in r: ${4 in r}')
    println('5 in r: ${5 in r}')
}
// @line: test_range_type.py:48:0
pub fn test_range_conversion() {
    mut r := py_range(5)
    println('list(r): ${[]Any(r)}')
    println('tuple(r): ${[]Any(r)}')
    println('set(r): ${map[string]bool(r)}')
}
// @line: test_range_type.py:54:0
pub fn test_range_with_enumerate() {
    for i, val in py_range(10, 20, 2) {
        println('i=${i}, val=${val}')
    }
}
// @line: test_range_type.py:58:0
pub fn test_range_nested() {
    for i in 0..3 {
        for j in 0..3 {
            print('(${i}, ${j}) ')
        }
        println('')
    }
}
// @line: test_range_type.py:64:0
pub fn test_range_large() {
    mut r := py_range(1000000)
    println('range(1000000) size: ${r.len}')
    println('range(1000000)[500000]: ${r[500000]}')
}
// @line: test_range_type.py:70:0
pub fn test_range_start_stop_step() {
    mut r := py_range(10, 2, -2)
    println('range(10, 2, -2): ${[]Any(r)}')
}
// @line: test_range_type.py:74:0
pub fn test() {
    test_range_basic()
    test_range_negative()
    test_range_iteration()
    test_range_indexing()
    test_range_slicing()
    test_range_len()
    test_range_membership()
    test_range_conversion()
    test_range_with_enumerate()
    test_range_nested()
    test_range_large()
    test_range_start_stop_step()
}

fn main() {
    // @line: test_range_type.py:88:0
    // if __name__ == '__main__':
    test()
}