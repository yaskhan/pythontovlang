module main

// @line: test_tuple_type.py:1:0
pub fn test_tuple_creation() {
    mut t1 := [1, 2, 3]
    println('Tuple: ${t1}')
    mut t2 := [1, 2, 3]
    println('Without parens: ${t2}')
    mut t3 := []Any([1, 2, 3])
    println('From list: ${t3}')
    t4 := [1]
    println('Single element: ${t4}')
    t5 := []
    println('Empty tuple: ${t5}')
}
// @line: test_tuple_type.py:19:0
pub fn test_tuple_access() {
    mut t := [10, 20, 30, 40, 50]
    println('t[0]: ${t[0]}')
    println('t[-1]: ${t[t.len - 1]}')
    println('t[1:4]: ${t[1..4]}')
    println('t[::2]: ${py_list_slice(t, none, none, 2)}')
}
// @line: test_tuple_type.py:26:0
pub fn test_tuple_unpacking() {
    mut t := [1, 2, 3]
    py_destruct_0 := t
    a := py_destruct_0[0]
    b := py_destruct_0[1]
    c := py_destruct_0[2]
    println('a=${a}, b=${b}, c=${c}')
    nested := [1, [2, 3], 4]
    py_destruct_1 := nested
    x := py_destruct_1[0]
    py_destruct_2 := py_destruct_1[1]
    y := py_destruct_2[0]
    z := py_destruct_2[1]
    w := py_destruct_1[2]
    println('x=${x}, y=${y}, z=${z}, w=${w}')
}
// @line: test_tuple_type.py:36:0
pub fn test_tuple_immutable() {
    mut t := [1, 2, 3]
    println('Tuple is immutable: ${t}')
    mut t2 := [[1, 2], [3, 4]]
    t2[0].append(3)
    println('Mutable inside tuple: ${t2}')
}
// @line: test_tuple_type.py:46:0
pub fn test_tuple_methods() {
    mut t := [1, 2, 3, 2, 4, 2, 5]
    println('Count of 2: ${(t as none).count(2)}')
    println('Index of 4: ${t.index(4) or { panic('ValueError: substring not found') }}')
}
// @line: test_tuple_type.py:51:0
pub fn test_tuple_concat() {
    mut t1 := [1, 2, 3]
    mut t2 := [4, 5, 6]
    mut result := t1 + t2
    println('Concat: ${result}')
}
// @line: test_tuple_type.py:57:0
pub fn test_tuple_repeat() {
    mut t := [1, 2]
    mut result := t * 3
    println('Repeat: ${result}')
}
// @line: test_tuple_type.py:62:0
pub fn test_tuple_membership() {
    mut t := [1, 2, 3, 4, 5]
    println('3 in tuple: ${3 in t}')
    println('10 not in tuple: ${10 !in t}')
}
// @line: test_tuple_type.py:67:0
pub fn test_tuple_comparison() {
    mut t1 := [1, 2, 3]
    mut t2 := [1, 2, 4]
    mut t3 := [1, 2, 3]
    println('t1 == t3: ${t1 == t3}')
    println('t1 < t2: ${t1 < t2}')
    println('t1 > t2: ${t1 > t2}')
}
// @line: test_tuple_type.py:76:0
pub fn test_named_tuple() {
    point := collections.namedtuple('Point', ['x', 'y'])
    p := point(3, 4)
    println('Point: ${p}')
    println('p.x: ${p.x}')
    println('p.y: ${p.y}')
    println('p[0]: ${p[0]}')
    py_destruct_3 := p
    x := py_destruct_3[0]
    y := py_destruct_3[1]
    println('Unpacked: x=${x}, y=${y}')
}
// @line: test_tuple_type.py:91:0
pub fn test_tuple_as_dict_key() {
    d := {[0, 0]: Any('origin'), [1, 1]: Any('diagonal')}
    println('Dict with tuple keys: ${d}')
    println('d[(0, 0)]: ${d[[0, 0]]}')
}
// @line: test_tuple_type.py:97:0
pub fn test_tuple_function_return() {
// @line: test_tuple_type.py:98:4
    mut get_min_max := fn (nums Any) Any {
        return [py_min(nums), py_max(nums)]
    }
    mut result := get_min_max([3, 1, 4, 1, 5, 9])
    println('Min and max: ${result}')
    py_destruct_4 := get_min_max([3, 1, 4, 1, 5, 9])
    min_val := py_destruct_4[0]
    max_val := py_destruct_4[1]
    println('Unpacked: min=${min_val}, max=${max_val}')
}
// @line: test_tuple_type.py:107:0
pub fn test() {
    test_tuple_creation()
    test_tuple_access()
    test_tuple_unpacking()
    test_tuple_immutable()
    test_tuple_methods()
    test_tuple_concat()
    test_tuple_repeat()
    test_tuple_membership()
    test_tuple_comparison()
    test_named_tuple()
    test_tuple_as_dict_key()
    test_tuple_function_return()
}

fn main() {
    // @line: test_tuple_type.py:121:0
    // if __name__ == '__main__':
    test()
}