module main

struct Matrix {

}
struct Formattable {

}
type RecursiveList = []RecursiveList
struct MyDict {
    x int
    y string
}

fn new_Matrix(v int) Matrix {
    self.v := v
}
fn (self Matrix) matmul(other int) {
    return Matrix(self.v * other.v)
}
fn (self Formattable) __format__(spec int) {
    return 'Formatted: ${spec}'
}
fn my_func() {
}

fn main() {
    m := Matrix(2)
    m = m.matmul(Matrix(3))
    f := Formattable()
    s := '${f.__format__("spec")}'
    b := py_bytes_format([u8(0x25), u8(0x73)], [u8(0x61)])
    my_func__attr := 10
    println('${my_func__attr}')
}