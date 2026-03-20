module main

pub const test_loop_destructuring__annotations__ = { 'items': '[]TupleStruct_IntString' }

// @line: repro_loop.py:2:0
pub fn test_loop_destructuring(items []TupleStruct_IntString) {
    for py_val_140054103778768 in items {
        x := py_val_140054103778768[0]
        y := py_val_140054103778768[1]
        println('${x} ${y}')
    }
}

fn main() {
    // @line: repro_loop.py:6:0
    // if __name__ == '__main__':
    test_loop_destructuring([[1, 'a'], [2, 'b']])
}