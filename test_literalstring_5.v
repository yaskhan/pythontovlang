module main

const (
    a = 'test'
)

fn bar() {
    a := 'test'
    b := 'a' + 'b'
}

fn main() {
    b := a + 'b'
}