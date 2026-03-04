module main

import os
import ast

pub fn test_class_default_TestPEP696() {
    source := 'class Box[T : __py2v_def__int]: pass
b: Box'
    v_code := self.transpiler.transpile(source)
    assert 'struct Box[T] {' in v_code
    assert 'mut b := Box[int]{}' in v_code
}
pub fn test_function_default_TestPEP696() {
    source = 'def foo[T : __py2v_def__str](x: T): pass'
    v_code = self.transpiler.transpile(source)
    assert 'fn foo[T](x T) {' in v_code
}
pub fn test_type_alias_default_TestPEP696() {
    source = 'type MyList[T : __py2v_def__int] = list[T]
l: MyList'
    v_code = self.transpiler.transpile(source)
    assert 'type MyList[T] = []T' in v_code
    assert 'mut l := []int{}' in v_code
}
pub fn test_multiple_defaults_TestPEP696() {
    source = 'class Map[K : __py2v_def__str, V : __py2v_def__int]: pass
m: Map[int]'
    v_code = self.transpiler.transpile(source)
    assert 'struct Map[K, V] {' in v_code
    assert 'mut m := Map[int, int]{}' in v_code
}

fn main() {
    // if __name__ == '__main__':
    // unittest.main() ignored
}