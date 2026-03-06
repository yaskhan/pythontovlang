module main

type SumType_IntString = int | string

pub fn is_str(val SumType_IntString) bool {
    return val is str
}
pub fn foo(x SumType_IntString) {
    if is_str(x) != 0 {
        println('${x}')
    } else {
        println('${x}')
    }
}
