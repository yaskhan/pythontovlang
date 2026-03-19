module main

pub const test_comp_destructuring__annotations__ = { 'items': '[]TupleStruct_IntString' }

// @line: repro_comp.py:2:0
pub fn test_comp_destructuring(items []TupleStruct_IntString) {
    mut res := []int{}
    for [x, y] in items {
        res << '${x}-${y}'
    }
    println('${res}')
}

fn main() {
    // @line: repro_comp.py:6:0
    // if __name__ == '__main__':
    test_comp_destructuring([[1, 'a'], [2, 'b']])
}