module main

import os

const (
    a = 'test'
    b = 'a' + 'b'
    c = '${a}b'
    d = os.input('')
)

fn main() {
    // WARNING: LiteralString variable 'd' receives value from input() (loss of guarantee)
}