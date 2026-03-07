module main

// @line: generics_complex.py:6:0
pub struct Pair[T, U] {
    first T
    second U
}
// @line: generics_complex.py:11:0
pub struct Container[T] {
    items []T
}
// @line: generics_complex.py:26:0
pub struct Box[T] {
    x T
}

// @line: generics_complex.py:7:4
pub fn new_pair[T, U](first T, second U) Pair[T, U] {
    mut self := Pair[T, U]{}
    self.first = first
    self.second = second
    return self
}
// @line: generics_complex.py:12:4
pub fn new_container[T](items []T) Container[T] {
    mut self := Container[T]{}
    self.items = items
    return self
}
// @line: generics_complex.py:15:0
pub fn py_main() {
    p := new_pair(1, 'hello')
    c := new_container([]f64{1.5, 2.5})
    nested := new_container([]int{Box(10), Box(20)})
    println('${p.first}')
    println('${p.second}')
    println('${py_subscript(c.items, 0)}')
}
// @line: generics_complex.py:27:4
pub fn new_box[T](x T) Box[T] {
    mut self := Box[T]{}
    self.x = x
    return self
}

fn main() {
    // @line: generics_complex.py:3:0
    // @line: generics_complex.py:4:0
    // @line: generics_complex.py:30:0
    // if __name__ == '__main__':
    py_main()
}