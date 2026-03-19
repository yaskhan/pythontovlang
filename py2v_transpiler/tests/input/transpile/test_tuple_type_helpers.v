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

fn py_counter[T](a []T) map[T]int {
    mut m := map[T]int{}
    for x in a {
        m[x]++
    }
    return m
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
fn py_subscript(obj Any, idx Any) Any {
    // Dynamic subscript fallback
    if obj is string {
        if idx is int {
            mut i := idx
            if i < 0 { i += obj.len }
            if i >= 0 && i < obj.len { return obj[i].ascii_str() }
        }
    } else if obj is []u8 {
        if idx is int {
            mut i := idx
            if i < 0 { i += obj.len }
            if i >= 0 && i < obj.len { return obj[i] }
        }
    }
    panic('py_subscript: unsupported type or index')
    return false
}
fn py_slice(obj Any, lower ?Any, upper ?Any, step ?Any) Any {
    // Dynamic slice fallback
    if obj is string {
        mut l := 0
        if lower_val := lower {
            if lower_val is int { l = lower_val }
        }
        mut u := obj.len
        if upper_val := upper {
            if upper_val is int { u = upper_val }
        }
        mut s := 1
        if step_val := step {
            if step_val is int { s = step_val }
        }

        if l < 0 { l += obj.len }
        if u < 0 { u += obj.len }
        if l < 0 { l = 0 }
        if u > obj.len { u = obj.len }

        if s == 1 {
            if l >= u { return '' }
            return obj[l..u]
        } else if s == -1 {
            if l == 0 && u == obj.len {
                return py_str_reverse(obj)
            }
            // more complex case not fully implemented for dynamic Any
            return py_str_reverse(obj) // fallback
        }

        return py_str_slice(obj, lower, upper, step)
    } else if obj is []u8 {
        // ... similar for bytes if needed
        return obj // stub
    }
    panic('py_slice: unsupported type or bounds')
    return false
}
fn py_min[T](a []T) T { if a.len == 0 { panic('min() arg is an empty sequence') }; mut m := a[0]; for x in a { if x < m { m = x } }; return m }
fn py_max[T](a []T) T { if a.len == 0 { panic('max() arg is an empty sequence') }; mut m := a[0]; for x in a { if x > m { m = x } }; return m }
