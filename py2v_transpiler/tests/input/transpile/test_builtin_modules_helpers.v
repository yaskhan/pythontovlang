module main

pub struct NoneType {}

pub fn (n NoneType) str() string {
    return 'None'
}

pub struct Interpolation {
pub:
    value       Any
    expression  string
    conversion  string
    format_spec string
}

pub struct Template {
pub:
    strings        []string
    interpolations []Interpolation
}

pub fn (t Template) values() []Any {
    mut res := []Any{cap: t.interpolations.len}
    for i in t.interpolations {
        res << i.value
    }
    return res
}

pub fn (t1 Template) + (t2 Template) Template {
    if t1.strings.len == 0 { return t2 }
    if t2.strings.len == 0 { return t1 }
    mut new_strings := t1.strings[..t1.strings.len - 1].clone()
    new_strings << t1.strings.last() + t2.strings[0]
    if t2.strings.len > 1 {
        new_strings << t2.strings[1..]
    }
    mut new_interpolations := t1.interpolations.clone()
    new_interpolations << t2.interpolations
    return Template{
        strings: new_strings
        interpolations: new_interpolations
    }
}

pub type Any = Interpolation | NoneType | Template | []Any | []u8 | bool | f64 | i64 | int | map[string]Any | string

pub enum PyAnnotationFormat { value forwardref string }

pub fn py_get_type_hints[T]() map[string]string {
    mut hints := map[string]string{}
    $for field in T.fields {
        hints[field.name] = field.typ
    }
    return hints
}

pub fn py_get_type_hints_generic(obj Any) map[string]string {
    return map[string]string{}
}

import os

struct PyGeneratorInput {
    val Any
    is_exc bool
    exc_msg string
}
struct PyGenerator[T] {
mut:
    out chan T
    in_ chan PyGeneratorInput
    open bool = true
}
struct PyZipItem[T, U] { a T; b U }
struct PyEnumerateItem[T] { index int; value T }
struct PyPathSplit { dir string; base string }
struct PyPathSplitExt { root string; ext string }

fn py_sorted[T](a []T) []T {
    mut b := a.clone()
    b.sort()
    return b
}
fn py_reversed[T](a []T) []T {
    mut b := a.clone()
    b.reverse()
    return b
}
fn py_round(number f64, ndigits int) f64 {
    p := math.pow(10, f64(ndigits))
    return math.round(number * p) / p
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
fn py_yield[T](ch_out chan T, ch_in chan PyGeneratorInput, val T) Any {
    ch_out <- val
    inp := <-ch_in
    if inp.is_exc {
        panic(inp.exc_msg)
    }
    return inp.val
}
//##LLM@@ String formatting for bytes is stubbed and might be incorrect. Please implement proper bytes formatting or use V string interpolation.
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
fn py_any[T](a []T) bool {
    for it in a {
        $if T is bool {
            if it { return true }
        } $else $if T is int {
            if it != 0 { return true }
        } $else $if T is i64 {
            if it != 0 { return true }
        } $else $if T is f64 {
            if it != 0.0 { return true }
        } $else $if T is string {
            if it.len > 0 { return true }
        } $else $if T is Any {
            if py_bool(it) { return true }
        } $else {
            if it != none { return true }
        }
    }
    return false
}
fn py_all[T](a []T) bool {
    for it in a {
        $if T is bool {
            if !it { return false }
        } $else $if T is int {
            if it == 0 { return false }
        } $else $if T is i64 {
            if it == 0 { return false }
        } $else $if T is f64 {
            if it == 0.0 { return false }
        } $else $if T is string {
            if it.len == 0 { return false }
        } $else $if T is Any {
            if !py_bool(it) { return false }
        } $else {
            if it == none { return false }
        }
    }
    return true
}
fn py_bool(val Any) bool {
    if val is bool { return val }
    if val is int { return val != 0 }
    if val is i64 { return val != 0 }
    if val is f64 { return val != 0.0 }
    if val is string { return val.len > 0 }
    if val is []Any { return val.len > 0 }
    if val is map[string]Any { return val.len > 0 }
    if val is NoneType { return false }
    return true
}
fn py_sum[T](a []T) T { mut s := T{}; for x in a { s += x }; return s }
fn py_min[T](a []T) T { if a.len == 0 { panic('min() arg is an empty sequence') }; mut m := a[0]; for x in a { if x < m { m = x } }; return m }
fn py_max[T](a []T) T { if a.len == 0 { panic('max() arg is an empty sequence') }; mut m := a[0]; for x in a { if x > m { m = x } }; return m }
fn py_zip[T, U](a []T, b []U) []PyZipItem[T, U] { mut res := []PyZipItem[T, U]{}; limit := if a.len < b.len { a.len } else { b.len }; for i in 0..limit { res << PyZipItem[T, U]{a: a[i], b: b[i]} }; return res }
fn py_enumerate[T](a []T) []PyEnumerateItem[T] { mut res := []PyEnumerateItem[T]{}; for i, x in a { res << PyEnumerateItem[T]{index: i, value: x} }; return res }
fn py_range(args ...int) []int { mut res := []int{}; if args.len == 1 { for i in 0..args[0] { res << i } } else if args.len == 2 { for i in args[0]..args[1] { res << i } } else if args.len == 3 { start := args[0]; stop := args[1]; step := args[2]; if step > 0 { for i := start; i < stop; i += step { res << i } } else if step < 0 { for i := start; i > stop; i += step { res << i } } }; return res }
fn py_random_sample[T](a []T, k int) []T { if k > a.len { panic('sample larger than population') }; mut res := []T{}; mut indices := []int{len: a.len}; for i in 0..a.len { indices[i] = i }; rand.shuffle(mut indices); for i in 0..k { res << a[indices[i]] }; return res }
fn py_os_path_split(path string) PyPathSplit { return PyPathSplit{ dir: os.dir(path), base: os.base(path) } }
fn py_os_path_splitext(path string) PyPathSplitExt { ext := os.file_ext(path); return PyPathSplitExt{ root: path[..path.len - ext.len], ext: ext } }
