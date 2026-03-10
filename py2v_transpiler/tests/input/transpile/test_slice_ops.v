module main

// @line: test_slice_ops.py:1:0
pub fn test_slice_basic() {
    mut lst := []int{cap: 10}
    lst << 0
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst << 6
    lst << 7
    lst << 8
    lst << 9
    println('lst[2:5]: ${lst[2..5]}')
    println('lst[:4]: ${lst[..4]}')
    println('lst[6:]: ${lst[6..]}')
    println('lst[:]: ${lst[..]}')
}
// @line: test_slice_ops.py:8:0
pub fn test_slice_negative() {
    mut lst := []int{cap: 10}
    lst << 0
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst << 6
    lst << 7
    lst << 8
    lst << 9
    println('lst[-3:]: ${lst[-3..]}')
    println('lst[:-3]: ${lst[..-3]}')
    println('lst[-5:-2]: ${lst[-5..-2]}')
}
// @line: test_slice_ops.py:14:0
pub fn test_slice_step() {
    mut lst := []int{cap: 10}
    lst << 0
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst << 6
    lst << 7
    lst << 8
    lst << 9
    println('lst[::2]: ${lst[..]}')
    println('lst[1::2]: ${lst[1..]}')
    println('lst[::3]: ${lst[..]}')
}
// @line: test_slice_ops.py:20:0
pub fn test_slice_reverse() {
    mut lst := []int{cap: 10}
    lst << 0
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst << 6
    lst << 7
    lst << 8
    lst << 9
    println('lst[::-1]: ${lst[..]}')
    println('lst[::-2]: ${lst[..]}')
    println('lst[7:2:-1]: ${lst[7..2]}')
}
// @line: test_slice_ops.py:26:0
pub fn test_slice_assignment() {
    mut lst := []int{cap: 5}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst.delete_many(1, (3) - (1))
    lst.insert_many(1, [10, 20])
    println('After lst[1:3] = [10, 20]: ${lst}')
    lst = []int{cap: 5}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst.delete_many(1, (3) - (1))
    lst.insert_many(1, [100])
    println('After lst[1:3] = [100]: ${lst}')
    lst = []int{cap: 5}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst.delete_many(1, (3) - (1))
    lst.insert_many(1, [10, 20, 30, 40])
    println('After lst[1:3] = [10, 20, 30, 40]: ${lst}')
}
// @line: test_slice_ops.py:39:0
pub fn test_slice_delete() {
    mut lst := []int{cap: 7}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst << 6
    lst << 7
    lst.delete(None)
    println('After del lst[2:5]: ${lst}')
}
// @line: test_slice_ops.py:44:0
pub fn test_slice_step_assignment() {
    mut lst := []int{cap: 5}
    lst << 0
    lst << 0
    lst << 0
    lst << 0
    lst << 0
    lst.delete_many(0, (lst.len) - (0))
    lst.insert_many(0, [1, 1, 1])
    println('After lst[::2] = [1, 1, 1]: ${lst}')
}
// @line: test_slice_ops.py:49:0
pub fn test_slice_string() {
    s := 'Hello, World!'
    println('s[0:5]: ${s[0..5]}')
    println('s[::-1]: ${s[..]}')
    println('s[7:-1]: ${s[7..-1]}')
}
// @line: test_slice_ops.py:55:0
pub fn test_slice_tuple() {
    t := [0, 1, 2, 3, 4, 5]
    println('t[1:4]: ${t[1..4]}')
    println('t[::-1]: ${t[..]}')
}
// @line: test_slice_ops.py:60:0
pub fn test_slice_out_of_bounds() {
    mut lst := []int{cap: 5}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    println('lst[0:100]: ${lst[0..100]}')
    println('lst[-100:100]: ${lst[-100..100]}')
}
// @line: test_slice_ops.py:65:0
pub fn test_slice_empty() {
    mut lst := []int{cap: 3}
    lst << 1
    lst << 2
    lst << 3
    println('lst[2:1]: ${lst[2..1]}')
    println('lst[5:10]: ${lst[5..10]}')
}
// @line: test_slice_ops.py:70:0
pub fn test_slice_copy() {
    mut lst := []int{cap: 5}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    mut copy := lst[..].clone()
    copy[0] = 100
    println('Original: ${lst}')
    println('Copy: ${copy}')
}
// @line: test_slice_ops.py:77:0
pub fn test() {
    test_slice_basic()
    test_slice_negative()
    test_slice_step()
    test_slice_reverse()
    test_slice_assignment()
    test_slice_delete()
    test_slice_step_assignment()
    test_slice_string()
    test_slice_tuple()
    test_slice_out_of_bounds()
    test_slice_empty()
    test_slice_copy()
}

fn main() {
    // @line: test_slice_ops.py:91:0
    // if __name__ == '__main__':
    test()
}