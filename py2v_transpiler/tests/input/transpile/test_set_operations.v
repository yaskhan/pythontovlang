module main

// @line: test_set_operations.py:1:0
pub fn test_set_creation() {
    s1 := {1: true, 2: true, 3: true, 4: true}
    println('${s1}')
    s2 := map[string]bool{}
    println('Empty set: ${s2}')
    s3 := py_set_from_list<map[string]bool>([1, 2, 2, 3, 3, 3])
    println('From list: ${s3}')
}
// @line: test_set_operations.py:14:0
pub fn test_set_add_remove() {
    mut s := {1: true, 2: true, 3: true}
    s[4] = true
    println('After add: ${s}')
    py_set_remove(mut s, 2)
    println('After remove: ${s}')
    s.delete(10)
    println('After discard: ${s}')
    popped := py_set_pop(mut s)
    println('Popped: ${popped}, Set: ${s}')
}
// @line: test_set_operations.py:28:0
pub fn test_set_operations() {
    mut a := {1: true, 2: true, 3: true, 4: true, 5: true}
    mut b := {4: true, 5: true, 6: true, 7: true, 8: true}
    println('Union: ${py_set_union(a, b)}')
    println('Union method: ${py_set_union(a, b)}')
    println('Intersection: ${py_set_intersection(a, b)}')
    println('Intersection method: ${py_set_intersection(a, b)}')
    println('Difference a-b: ${py_set_difference(a, b)}')
    println('Difference b-a: ${py_set_difference(b, a)}')
    println('Symmetric diff: ${py_set_xor(a, b)}')
}
// @line: test_set_operations.py:47:0
pub fn test_set_update_operations() {
    mut a := {1: true, 2: true, 3: true}
    mut b := {3: true, 4: true, 5: true}
    py_set_update(mut a, b)
    println('After update: ${a}')
    a = {1: true, 2: true, 3: true}
    py_set_intersection_update(mut a, b)
    println('After intersection_update: ${a}')
    a = {1: true, 2: true, 3: true}
    py_set_difference_update(mut a, b)
    println('After difference_update: ${a}')
    a = {1: true, 2: true, 3: true}
    py_set_xor_update(mut a, b)
    println('After symmetric_difference_update: ${a}')
}
// @line: test_set_operations.py:66:0
pub fn test_set_subset_superset() {
    mut a := {1: true, 2: true, 3: true, 4: true, 5: true}
    mut b := {2: true, 3: true, 4: true}
    println('b is subset of a: ${py_set_subset(b, a)}')
    println('a is superset of b: ${py_set_superset(a, b)}')
    println('b <= a: ${py_set_subset(b, a)}')
    println('a >= b: ${py_set_superset(a, b)}')
}
// @line: test_set_operations.py:75:0
pub fn test_set_clear_copy() {
    mut s := {1: true, 2: true, 3: true}
    s_copy := s.clone()
    println('Copy: ${s_copy}')
    /* s.clear() */ s = {}
    println('After clear: ${s}')
    println('Copy after clear: ${s_copy}')
}
// @line: test_set_operations.py:84:0
pub fn test_set_membership() {
    mut s := {10: true, 20: true, 30: true}
    println('20 in s: ${20 in s}')
    println('40 not in s: ${40 !in s}')
}
// @line: test_set_operations.py:89:0
pub fn test_frozenset() {
    fs := py_set_from_list<map[string]bool>([1, 2, 3])
    println('Frozenset: ${fs}')
}
// @line: test_set_operations.py:95:0
pub fn test() {
    test_set_creation()
    test_set_add_remove()
    test_set_operations()
    test_set_update_operations()
    test_set_subset_superset()
    test_set_clear_copy()
    test_set_membership()
    test_frozenset()
}

fn main() {
    // @line: test_set_operations.py:105:0
    // if __name__ == '__main__':
    test()
}