module main

struct Base {

}
struct TestClass {
    Base
}

fn (self Base) method() {
}
fn (self TestClass) method() {
    self.Base.method()
    self.Base
}
fn test_del_slice() {
    l := [1, 2, 3, 4, 5]
    l.delete_many(1, 3 - 1)
    l.delete_many(0, 1 - 0)
    l.delete_many(1, l.len - 1)
}
fn test_chained_assign() {
    _assign_tmp_1 := 1
    a := _assign_tmp_1
    b := _assign_tmp_1
    c := _assign_tmp_1
}
fn test_loops() {
    mut _loop_else_2 := true
    for i in 0..3 {
    }
    if _loop_else_2 {
        println('For else')
    }
    mut _loop_else_3 := true
    for false {
    }
    if _loop_else_3 {
        println('While else')
    }
}
fn test_try() {
    // try {
    println('Try')
    // } except {
    // Handler: None
    // ... exception handling logic ...
    // } else {
    // (Executing else block assuming no exception)
    println('Else')
    // } finally {
    defer {
        println('Finally')
    }
}
fn test_raise() {
    // try {
    panic('Error' + ' (caused by: none)')
    // } except {
    // Handler: None
    // ... exception handling logic ...
}
fn test_unpacking() {
    l1 := [1, 2]
    l2 := py_list_concat([0], l1, [3])
    t1 := [1, 2]
    t2 := py_list_concat(t1, [3])
    s1 := map[int]bool{1: true, 2: true}
    s2 := py_dict_merge(s1, map[int]bool{3: true})
    d1 := map[string]int{'a': 1}
    d2 := py_dict_merge(map[string]int{'b': 2}, d1)
}
fn py_list_concat[T](args ...[]T) []T {
    mut res := []T{}
    for arg in args {
        res << arg
    }
    return res
}
fn py_dict_merge[K, V](args ...map[K]V) map[K]V {
    mut res := map[K]V{}
    for arg in args {
        for k, v in arg {
            res[k] = v
        }
    }
    return res
}
