module main

import os

fn foo() {
    a := 'test'
    b := 'a' + 'b'
    c := '${a}b'
    // WARNING: LiteralString variable 'd' receives value from input() (loss of guarantee)
    d := os.input('')
}
