module main

pub const test_tuple_destructuring__annotations__ = { 'coords': 'TupleStruct_IntString' }

// @line: repro_issue.py:2:0
pub fn test_tuple_destructuring(coords TupleStruct_IntString) {
    py_destruct_0 := coords
    x := py_destruct_0[0]
    y := py_destruct_0[1]
    println('${x} ${y}')
}

fn main() {
    // @line: repro_issue.py:6:0
    // if __name__ == '__main__':
    test_tuple_destructuring(TupleStruct_IntString{it_0: 1, it_1: 'hello'})
}