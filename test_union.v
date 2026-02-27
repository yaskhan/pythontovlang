module main

fn foo(x int | string) {
}
fn bar(x ?int) {
}
fn py_format(val any, spec string) string {
    // Dynamic format specifier support is limited.
    // V does not support runtime format string construction easily.
    // We fallback to standard string representation.
    return '${val}'
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
