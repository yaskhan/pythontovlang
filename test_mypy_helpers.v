module main

import os

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

struct PyCompletedProcess {
    returncode int
    stdout string
    stderr string
}
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

fn py_subprocess_run(args []string) PyCompletedProcess {
    if args.len == 0 { return PyCompletedProcess{returncode: 1, stdout: '', stderr: 'No arguments'} }
    mut p := os.new_process(args[0])
    p.set_args(args[1..])
    p.set_redirect_stdio()
    p.run()
    p.wait()
    res := PyCompletedProcess{returncode: p.code, stdout: p.stdout_slurp(), stderr: p.stderr_slurp()}
    p.close()
    return res
}
fn py_subprocess_call(args []string) int {
    if args.len == 0 { return 1 }
    mut p := os.new_process(args[0])
    p.set_args(args[1..])
    p.run()
    p.wait()
    code := p.code
    p.close()
    return code
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
    if arg is u64 { return arg.str() }
    if arg is f64 { return arg.str() }
    if arg is bool { return arg.str() }
    return '${arg}'
}
fn py_bytes_format(fmt []u8, args Any) []u8 {
    fmt_str := fmt.bytestr()
    mut values := []string{}
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
