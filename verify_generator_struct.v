module main

struct PyGenerator[T] {
mut:
    out chan ?T
    in_ chan any
    open bool = true
}

fn my_gen(ch_out chan ?int, ch_in chan any) {
    x := py_yield(ch_out, ch_in, 1)
    py_yield(ch_out, ch_in, x + 1)
    _ := <-ch_in
    x := py_yield(ch_out, ch_in, 1)
    py_yield(ch_out, ch_in, x + 1)
    ch_out.close()
}
fn usage() {
    ch_1 := chan ?int{cap: 0}
    ch_in_1 := chan any{cap: 0}
    gen_1 := PyGenerator[int]{out: ch_1, in_: ch_in_1}
    spawn my_gen(ch_1, ch_in_1)
    g := gen_1
    val := g.next()
    val2 := g.send(2)
    ch_2 := chan ?int{cap: 0}
    ch_in_2 := chan any{cap: 0}
    gen_2 := PyGenerator[int]{out: ch_2, in_: ch_in_2}
    spawn my_gen(ch_2, ch_in_2)
    g := gen_2
    val := g.next()
    val2 := g.send(2)
}
fn py_format(val any, spec string) string {
    // Dynamic format specifier support is limited.
    // V does not support runtime format string construction easily.
    // We fallback to standard string representation.
    return '${val}'
}
fn (mut g PyGenerator[T]) next() ?T {
    if !g.open { return none }
    g.in_ <- 0 // Send dummy value to trigger yield
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) send(val any) ?T {
    if !g.open { panic('StopIteration') }
    g.in_ <- val
    res := <-g.out
    if res == none { g.open = false }
    return res
}
fn (mut g PyGenerator[T]) close() {
    g.open = false
    g.in_.close()
    // g.out will be closed by the generator function loop when it detects in_ closed or panic
}
fn py_yield[T](ch_out chan ?T, ch_in chan any, val T) any {
    ch_out <- val
    res := <-ch_in
    return res
}
fn py_bytes_format(fmt []u8, args any) []u8 {
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
