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

import math
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
fn py_bytes_format_arg(arg Any) string {
    if arg is []u8 { return arg.bytestr() }
    if arg is string { return arg }
    if arg is int { return arg.str() }
    if arg is i64 { return arg.str() }
    if arg is f64 { return arg.str() }
    if arg is bool { return arg.str() }
    return '${arg}'
}

fn py_bytes_format(fmt []u8, args Any) []u8 {
    fmt_str := fmt.bytestr()
    mut arg_list := []Any{}
    if args is []Any {
        arg_list = args
    } else {
        arg_list = [args]
    }

    mut res := strings.new_builder(fmt_str.len + 16)
    mut arg_idx := 0
    mut i := 0
    for i < fmt_str.len {
        if fmt_str[i] == `%` {
            if i + 1 < fmt_str.len {
                if fmt_str[i+1] == `%` {
                    res.write_string('%')
                    i += 2
                    continue
                }
                // Parse flags
                mut j := i + 1
                mut flag_zero := false
                mut flag_minus := false
                for j < fmt_str.len {
                    if fmt_str[j] == `0` {
                        flag_zero = true
                        j++
                    } else if fmt_str[j] == `-` {
                        flag_minus = true
                        j++
                    } else {
                        break
                    }
                }
                // Parse width
                mut width := 0
                mut width_str := ''
                for j < fmt_str.len && fmt_str[j].is_digit() {
                    width_str += fmt_str[j].ascii_str()
                    j++
                }
                if width_str != '' {
                    width = width_str.int()
                }
                // Parse precision
                mut precision := -1
                if j < fmt_str.len && fmt_str[j] == `.` {
                    j++
                    mut prec_str := ''
                    for j < fmt_str.len && fmt_str[j].is_digit() {
                        prec_str += fmt_str[j].ascii_str()
                        j++
                    }
                    if prec_str != '' {
                        precision = prec_str.int()
                    } else {
                        precision = 0
                    }
                }
                // Parse specifier
                if j < fmt_str.len {
                    spec := fmt_str[j]
                    if arg_idx >= arg_list.len {
                        res.write_string('%')
                        i++
                        continue
                    }
                    arg := arg_list[arg_idx]
                    arg_idx++

                    mut s_val := ''
                    if spec == `s` || spec == `r` || spec == `a` {
                        s_val = py_bytes_format_arg(arg)
                    } else if spec == `d` || spec == `i` || spec == `u` {
                        // Integer formatting
                        if arg is int {
                            s_val = '${arg}'
                        } else if arg is i64 {
                            s_val = '${arg}'
                        } else if arg is f64 {
                            s_val = '${int(arg)}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int}'
                        }
                        if flag_zero && width > s_val.len && !flag_minus {
                             s_val = '0'.repeat(width - s_val.len) + s_val
                        }
                    } else if spec == `f` || spec == `F` {
                        // Float formatting
                        prec := if precision >= 0 { precision } else { 6 }
                        mut f_val := 0.0
                        if arg is f64 { f_val = arg }
                        else if arg is int { f_val = f64(arg) }
                        else if arg is i64 { f_val = f64(arg) }
                        else { f_val = '${arg}'.f64() }
                        s_val = strconv.format_f64(f_val, `f`, prec, 64)
                        if spec == `F` { s_val = s_val.to_upper() }
                    } else if spec == `x` {
                        if arg is int {
                            s_val = '${arg:x}'
                        } else if arg is i64 {
                            s_val = '${arg:x}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int:x}'
                        }
                    } else if spec == `X` {
                        if arg is int {
                            s_val = '${arg:X}'
                        } else if arg is i64 {
                            s_val = '${arg:X}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int:X}'
                        }
                    } else if spec == `o` {
                        if arg is int {
                            s_val = '${arg:o}'
                        } else if arg is i64 {
                            s_val = '${arg:o}'
                        } else {
                            val_int := '${arg}'.int()
                            s_val = '${val_int:o}'
                        }
                    } else if spec == `c` {
                        if arg is int {
                            s_val = u8(arg).ascii_str()
                        } else if arg is i64 {
                            s_val = u8(arg).ascii_str()
                        } else if arg is f64 {
                            s_val = u8(int(arg)).ascii_str()
                        } else {
                            val_int := '${arg}'.int()
                            s_val = u8(val_int).ascii_str()
                        }
                    } else {
                        s_val = py_bytes_format_arg(arg)
                    }

                    // Apply width/align
                    if width > s_val.len {
                        pad := width - s_val.len
                        if flag_minus {
                            s_val = s_val + ' '.repeat(pad)
                        } else if !flag_zero || spec == `s` {
                             s_val = ' '.repeat(pad) + s_val
                        }
                    }
                    res.write_string(s_val)
                    i = j + 1
                    continue
                }
            }
        }
        res.write_u8(fmt_str[i])
        i++
    }
    return res.str().bytes()
}

    if args is []Any {
        for a in args {
            values << py_bytes_format_arg(a)
        }
    } else if args is []string {
        for a in args {
            values << a
        }
    } else if args is [][]u8 {
        for a in args {
            values << a.bytestr()
        }
    } else {
        values << py_bytes_format_arg(args)
    }

    mut res := ''
    mut i := 0
    mut arg_idx := 0
    for i < fmt_str.len {
        if fmt_str[i] == `%` {
            if i + 1 < fmt_str.len && fmt_str[i + 1] == `%` {
                res += '%'
                i += 2
                continue
            }
            if i + 1 < fmt_str.len && arg_idx < values.len {
                spec := fmt_str[i + 1]
                if spec == `s` || spec == `r` || spec == `a` || spec == `d` || spec == `i` || spec == `u` || spec == `f` || spec == `x` || spec == `X` {
                    res += values[arg_idx]
                    arg_idx++
                    i += 2
                    continue
                }
            }
        }
        res += fmt_str[i].ascii_str()
        i++
    }
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
fn py_list_from_iter[T, U](mut it U) T { mut res := []Any{}; for { val := it.next() or { break }; res << val }; return T(res) }
fn py_sum[T](a []T) T { mut s := T{}; for x in a { s += x }; return s }
fn py_min[T](a []T) T { if a.len == 0 { panic('min() arg is an empty sequence') }; mut m := a[0]; for x in a { if x < m { m = x } }; return m }
fn py_max[T](a []T) T { if a.len == 0 { panic('max() arg is an empty sequence') }; mut m := a[0]; for x in a { if x > m { m = x } }; return m }
fn py_zip[T, U](a []T, b []U) []PyZipItem[T, U] { mut res := []PyZipItem[T, U]{}; limit := if a.len < b.len { a.len } else { b.len }; for i in 0..limit { res << PyZipItem[T, U]{a: a[i], b: b[i]} }; return res }
fn py_enumerate[T](a []T) []PyEnumerateItem[T] { mut res := []PyEnumerateItem[T]{}; for i, x in a { res << PyEnumerateItem[T]{index: i, value: x} }; return res }
fn py_range(args ...int) []int { mut res := []int{}; if args.len == 1 { for i in 0..args[0] { res << i } } else if args.len == 2 { for i in args[0]..args[1] { res << i } } else if args.len == 3 { start := args[0]; stop := args[1]; step := args[2]; if step > 0 { for i := start; i < stop; i += step { res << i } } else if step < 0 { for i := start; i > stop; i += step { res << i } } }; return res }
fn py_divmod[T](a T, b T) []T {
    $if T is f64 {
        q := math.floor(a / b)
        r := a - q * b
        return [q, r]
    } $else {
        return [a / b, a % b]
    }
}
fn py_os_path_split(path string) []string { return [os.dir(path), os.base(path)] }
fn py_os_path_splitext(path string) []string { ext := os.file_ext(path); return [path[..path.len - ext.len], ext] }
