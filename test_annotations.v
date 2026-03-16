module main

// @line: test_annotations.py:3:0
pub struct A {
    x int
    y string
}

// @line: test_annotations.py:7:0
pub fn py_main() {
    println('${typing.get_type_hints(A)}')
}

fn main() {
    // @line: test_annotations.py:10:0
    // if __name__ == '__main__':
    py_main()
}