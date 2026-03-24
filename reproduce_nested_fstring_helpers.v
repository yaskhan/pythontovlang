module main

import strconv

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

fn py_format(val Any, spec string) string {
    // Basic implementation of Python-style formatting
    // Supports: [fill][align][sign][#][0][width][grouping][.precision][type]
    if spec == '' {
        if val is string { return val }
        if val is int { return val.str() }
        if val is i64 { return val.str() }
        if val is f64 { return val.str() }
        if val is bool { return val.str() }
        return '${val}'
    }

    mut fill := ` `
    mut align := `>` // Default for numbers is >, for others is <. Python is complex.

    mut s := spec
    // Alignment
    if s.len >= 2 && (s[1] == `<` || s[1] == `>` || s[1] == `^` || s[1] == `=`) {
        fill = s[0]
        align = s[1]
        s = s[2..]
    } else if s.len >= 1 && (s[0] == `<` || s[0] == `>` || s[0] == `^` || s[0] == `=`) {
        align = s[0]
        s = s[1..]
    }

    // Width
    mut width := 0
    mut j := 0
    for j < s.len && s[j].is_digit() {
        j++
    }
    if j > 0 {
        width = s[..j].int()
        s = s[j..]
    }

    // Precision
    mut precision := -1
    if s.starts_with('.') {
        s = s[1..]
        mut k := 0
        for k < s.len && s[k].is_digit() {
            k++
        }
        if k > 0 {
            precision = s[..k].int()
            s = s[k..]
        }
    }

    // Type
    typ := if s.len > 0 { s[s.len-1] } else { `s` }

    // Simplified formatting
    mut formatted := ''
    if val is f64 {
        prec := if precision >= 0 { precision } else { 6 }
        formatted = strconv.format_f64(val, typ.to_lower(), prec, 64)
        if typ.is_upper() { formatted = formatted.to_upper() }
    } else if val is int {
        formatted = '${val}'
    } else if val is i64 {
        formatted = '${val}'
    } else if val is string {
        formatted = val
    } else {
        formatted = '${val}'
    }

    if width > formatted.len {
        pad_len := width - formatted.len
        if align == `<` {
            formatted = formatted + fill.ascii_str().repeat(pad_len)
        } else if align == `>` {
            formatted = fill.ascii_str().repeat(pad_len) + formatted
        } else if align == `^` {
            left := pad_len / 2
            right := pad_len - left
            formatted = fill.ascii_str().repeat(left) + formatted + fill.ascii_str().repeat(right)
        }
    }

    return formatted
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
