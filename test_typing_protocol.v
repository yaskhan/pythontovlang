module main

// @line: test_typing_protocol.py:6:0

pub interface Iterable[T] {
    iter()
}

// @line: test_typing_protocol.py:9:0

pub interface Awaitable[T, U] {
    await_()
}


fn main() {
    // @line: test_typing_protocol.py:3:0
    // @line: test_typing_protocol.py:4:0
}