module main

type Any = bool | int | i64 | f64 | string | []u8
struct MyDict {
    a int
    b string
}
struct PyGeneratorInput {
    val Any
    is_exc bool
    exc_msg string
}
struct PyGenerator[T] {
mut:
    out chan ?T
    in_ chan PyGeneratorInput
    open bool = true
}

fn py_format(val Any, spec string) string {
    // Dynamic format specifier support is limited.
    // V does not support runtime format string construction easily.
    // We fallback to standard string representation.
    return '${val}'
}
fn (mut g PyGenerator[T]) next() ?T {
    if !g.open { return none }
    g.in_ <- PyGeneratorInput{val: 0} // Send dummy value
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) send(val Any) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{val: val}
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) throw(msg string) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- PyGeneratorInput{is_exc: true, exc_msg: msg}
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) close() {
    g.open = false
    g.in_.close()
    // g.out will be closed by the generator function loop when it detects in_ closed or panic
}
fn py_yield[T](ch_out chan ?T, ch_in chan PyGeneratorInput, val T) Any {
    ch_out <- val
    inp := <-ch_in
    if inp.is_exc {
        panic(inp.exc_msg)
    }
    return inp.val
}
fn py_bytes_format(fmt []u8, args Any) []u8 {
    // Simplistic implementation for b'%s' % b'val'
    // Converts bytes to string, formats, and converts back.
    // This is not efficient or correct for non-ASCII bytes but works for simple cases.
    fmt_str := fmt.bytestr()
    // TODO: handle args properly. V's string interpolation/formatting expects distinct args.
    // If args is []u8, treat as string.
    arg_str := if args is []u8 { args.bytestr() } else { '${args}' }

    // Manual substitution of %s
    // V does not have sprintf for runtime strings easily available in core without C interop.
    // Simple replace for %s
    res := fmt_str.replace('%s', arg_str)
    return res.bytes()
}

fn main() {
    d := map[string]int{'a': 1, 'b': 'hello'}
    d['a'] := 2
}