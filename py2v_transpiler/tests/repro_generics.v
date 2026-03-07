module main

// @line: repro_generics.py:5:0
pub struct Box[T] {
    x T
}

// @line: repro_generics.py:6:4
pub fn new_box[T](x T) Box[T] {
    mut self := Box[T]{}
    self.x = x
    return self
}
// @line: repro_generics.py:9:0
pub fn py_main() {
    b := new_box(10)
    println('${b.x}')
}

fn main() {
    // @line: repro_generics.py:3:0
    // @line: repro_generics.py:13:0
    // if __name__ == '__main__':
    py_main()
}