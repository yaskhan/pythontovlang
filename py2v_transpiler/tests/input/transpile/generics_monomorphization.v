module main

// @line: generics_monomorphization.py:5:0
pub struct Box[T] {
    x int
}

// @line: generics_monomorphization.py:6:4
pub fn new_box[T](x T) Box[T] {
    mut self := Box[T]{}
    self.x = x
    return self
}
// @line: generics_monomorphization.py:9:0
pub fn factory(x int) Box[int] {
    return new_box[int](x)
}
// @line: generics_monomorphization.py:12:0
pub fn py_main() {
    b := factory(10)
    println('${b.x}')
}

fn main() {
    // @line: generics_monomorphization.py:3:0
    // @line: generics_monomorphization.py:16:0
    // if __name__ == '__main__':
    py_main()
}