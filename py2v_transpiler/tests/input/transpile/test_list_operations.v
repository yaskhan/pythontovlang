module main

// @line: test_list_operations.py:1:0
pub fn test_list_append_extend() {
    mut lst := []int{cap: 3}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    println('${lst}')
    lst << [5, 6, 7]
    println('${lst}')
}
// @line: test_list_operations.py:9:0
pub fn test_list_insert_remove() {
    mut lst := []int{cap: 4}
    lst << 1
    lst << 2
    lst << 4
    lst << 5
    lst.insert(2, 3)
    println('${lst}')
    py_list_remove(mut lst, 3)
    println('${lst}')
}
// @line: test_list_operations.py:17:0
pub fn test_list_pop_clear() {
    mut lst := []int{cap: 4}
    lst << 10
    lst << 20
    lst << 30
    lst << 40
    popped := lst.pop()
    println('Popped: ${popped}, List: ${lst}')
    popped2 := py_list_pop_at(mut lst, 1)
    println('Popped at index: ${popped2}, List: ${lst}')
    /* lst.clear() */ lst = []
    println('Cleared: ${lst}')
}
// @line: test_list_operations.py:28:0
pub fn test_list_index_count() {
    mut lst := []int{cap: 7}
    lst << 1
    lst << 2
    lst << 3
    lst << 2
    lst << 4
    lst << 2
    lst << 5
    idx := lst.index(3) or { panic('ValueError: substring not found') }
    println('Index of 3: ${idx}')
    cnt := lst.filter(it == 2).len
    println('Count of 2: ${cnt}')
}
// @line: test_list_operations.py:36:0
pub fn test_list_sort_reverse() {
    mut lst := []int{cap: 5}
    lst << 5
    lst << 2
    lst << 8
    lst << 1
    lst << 9
    lst.reverse()
    println('Reversed: ${lst}')
    lst.sort()
    println('Sorted: ${lst}')
    lst.sort(a > b)
    println('Sorted desc: ${lst}')
    words := ['banana', 'pie', 'Washington', 'book']
    words.sort()
    println('Sorted by length: ${words}')
}
// @line: test_list_operations.py:52:0
pub fn test_list_slicing_assignment() {
    mut lst := []int{cap: 5}
    lst << 1
    lst << 2
    lst << 3
    lst << 4
    lst << 5
    lst.delete_many(1, (3) - (1))
    lst.insert_many(1, [10, 20])
    println('${lst}')
    lst.delete_many(0, (lst.len) - (0))
    lst.insert_many(0, [100, 200, 300])
    println('${lst}')
}
// @line: test_list_operations.py:60:0
pub fn test_list_unpacking() {
    a, b, c := 1, 2, 3
    println('a=${a}, b=${b}, c=${c}')
    py_destruct_0 := [1, 2, 3, 4, 5]
    first := py_destruct_0[0]
    middle := py_destruct_0[1..py_destruct_0.len-1]
    last := py_destruct_0[py_destruct_0.len-1]
    println('First: ${first}, Middle: ${middle}, Last: ${last}')
    py_destruct_1 := [10, 20, 30, 40]
    start := py_destruct_1[0..py_destruct_1.len-1]
    end := py_destruct_1[py_destruct_1.len-1]
    println('Start: ${start}, End: ${end}')
}
// @line: test_list_operations.py:71:0
pub fn test_list_methods_chain() {
    mut lst := []int{cap: 8}
    lst << 3
    lst << 1
    lst << 4
    lst << 1
    lst << 5
    lst << 9
    lst << 2
    lst << 6
    lst << 5
    lst.sort()
    println('Sorted with append: ${lst}')
}
// @line: test_list_operations.py:78:0
pub fn test() {
    test_list_append_extend()
    test_list_insert_remove()
    test_list_pop_clear()
    test_list_index_count()
    test_list_sort_reverse()
    test_list_slicing_assignment()
    test_list_unpacking()
    test_list_methods_chain()
}

fn main() {
    // @line: test_list_operations.py:88:0
    // if __name__ == '__main__':
    test()
}