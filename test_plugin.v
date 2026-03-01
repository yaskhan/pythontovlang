module main

struct A {

}
struct B {

}

fn new_A(x int) A {
    self.x := x
}

fn main() {
    a := new_A(1)
    b := B{}
}