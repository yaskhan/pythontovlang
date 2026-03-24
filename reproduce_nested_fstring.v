module main

fn init() {
    // @line: reproduce_nested_fstring.py:1:0
    x := 1.23456
    // @line: reproduce_nested_fstring.py:2:0
    p := 2
    // @line: reproduce_nested_fstring.py:3:0
    println('${py_format(x, ".${p}f")}')
}
