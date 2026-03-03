module main

import os

const (
    a = 'test'
)

fn bar() {
    a := 'test'
    b := 'a' + 'b'
    c := '${a}b'
    d := os.input('')
    e := 1
}

fn main() {
    b := a + 'b'
    c := '${a}b'
    d := os.input('')
    e := 1
}