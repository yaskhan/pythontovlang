module mypy

pub struct NoneType {
pub mut:
	line int = -1
}

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
