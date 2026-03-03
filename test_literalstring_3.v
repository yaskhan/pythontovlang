module main

import os

__global (
    f string
)

const (
    e = 'test'
)

fn foo() {
    a := 'test'
    b := 'a' + 'b'
    c := '${a}b'
    // WARNING: LiteralString variable 'd' receives value from input() (loss of guarantee)
    d := os.input('')
}

fn init() {
    f = os.input('')
}

fn main() {
    // WARNING: LiteralString variable 'f' receives value from input() (loss of guarantee)
}